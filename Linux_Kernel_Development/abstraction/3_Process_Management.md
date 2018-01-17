# 3. Process Management

## 단순 정리

### The Process
process 란?
 * 프로그램의 실행
 * a set of resources
    * open files
    * pending signals
    * kernel data
    * processor state
    * memory address space
    * one or more threads of execution
    * data section
    
    
thread 란?
 * 구성요소
    * unique program counter
    * process stack
    * set of processor registers
    
사실상 커널은 thread 를 스케줄 한다.
 * 커널은 process 가 뭔지 모름.
 * 전통적인 Unix system 은 1 process = 1 thread.
 * 요즘은 1 process 가 여러개 스레드 가지지만 스케줄링 단위는 thread 이다.
 * Linux는  unique thread implementation 을 가짐. process 구현이 따로 있는게 아님.
 * **To Linux, a thread is a special kind of process.**
 
현대 OS가 가상화 하는 두가지.
 1. virtualized processor
    * process 는 자기 혼자 processor 를 쓰는 걸로 앎
    * [Chapter 4 "Process Scheduling"]() 에서 자세히 배움
 2. virtual memory
    * process 가 사용할 메모리를 할당해 주고, process 는 시스템의 모든 메모리를 가지고 쓰는 것 처럼 관리해준다.
    * [Chapter 12 "Memory Management"]() 에서 자세히 배움
 * `프로세스 내의 스레드들은 virtual memory 는 공유, 하지만 각자 자신의 virtualized processor 를 받음`
 
 ### Process Descriptor and Task Structure
 
 ```c
 struct task_struct{
    unsinged long state;
    int prio;
    unsinged long policy;
    struct task_strct * parent;
    struct list_head tasks;
    pid_t pid;
 
 }
```

process descriptor 는 struct task_struct 여기에 프로세스에 대한 모든 정보가 다 담겨있다.

#### Allocating the Process Descriptor

task_struct 구조체는 slab allocator 에 의해 할당됨.
 * slab allocator provide object reuse and cache coloring.
 
kernel 2.6 이전에는 task_struct 는 각 프로세스의 kernel stack 의 맨 마지막에 저장되었음
 * 이렇게 하면 register 가 적은 architecture 에서 따로 위치를 저장하지 않아도 stack pointer 로 바로 process descriptor 를 가리킬 수 있음

```c
struct thread_info{
    struct task_struct  *task;
    struct exec_domain  *exec_domain;
    __u32               flags;
    __u32               status;
    __u32               cpu;
    int                 preempt_count;
    mm_segment_t        addr_limit;
    struct restart_block restart_block;
    void                *sysenter_return;
    int                 uaccess_err;
}
```
new structure (2.6 부터?)
 * slab allocator 가 struct thread_info 를 동적으로 할당.
    * thread_info structure 는 항상 해당 stack 의 맨 마지막에(최초생성) 있음.
        * bottom of the stack (for stacks that grow down)
        * top of the stack (for stacks that grow up)
        
#### Storing the Process Descriptor
pid 로 process를 식별한다
  * pid_t type (내부적으로 int 값임)
    * 단 max 는 32,768 (short int) - compatibility 때문
  * 동시에 max 값 만큼의 프로세스가 돌 수 있음.
  * 클 수록 나중에 실행된 프로세스
  * max 값을 올릴 수는 있음
    * /proc/sys/kernel/pid_max 에서
    * 단, old application 이랑 compatibility 깨짐
    
`current` macro 로 현재 수행중인 task 의 task_struct 에 바로 접근할 수 있음.
 * x86 은 13 least-significant bits of the stack pointer 마스킹으로 current 를 계산해서 thread_info 구조체를 가져옴.
    * current_thread_info()
 * task_struct 는 `current_thread_info()->task;` 로 가져온다

```assembly
// eax = 32bit 범용 레지스터
// esp = stack pointer
movl $-8192, %eax   // 레지스터가 가지는 주소위치 8KB stack move
andl %esp, %eax     // 레지스터에 stack pointer and 연산
//* %esp가 가리키는 stack pointer 는 8KB 의 stack 공간을 쓸 수 있다.
```

#### Process State
![Flow chart of process states](http://4.bp.blogspot.com/-k9KDTfkN8Gs/UxILiXK0sOI/AAAAAAAAA1c/7I_LlZ9xiwI/s1600/03fig03.gif)

task_struct 의 state 값으로 프로세스의 현재 상태를 알 수 있음 
 * TASK_RUNNING - The process is runnable.
    * running 중이거나 run-queue 에서 waiting 중 (runqueues in [Chapter4)]())
 * TASK_INTERRUPTIBLE - The process is sleeping(blocked), waiting for some condition to exit.
    * 깨어날 조건이 존재하면 kernel 이 signal 을 보내서 TASK_RUNNING 상태로 바꿈
 * TASK_UNINTERRUPTIBLE - 깨어날 수 없는 상태. (그 외의 조건은 TASK_INTERRUPTIBLE 이랑 같음)
    * interrupt 되지 않고 기다려야 하는 상황.
 * __TASK_TRACED - The process is being traced by another process, such as a debugger, via _ptrace_.
 * __TASK_STOPPED - Process execution has stooped.
    * running 도 아니고 running 가능한 상태도아님.
    * signal 을 받았을 때. (SIGSTOP, SIGTSTP, SIGTTIN, SIGTTOU)
    * 디버깅 하는 다른 signal 받앗을 때

#### Manipulating the Current Process State
`set_task_state(task, state);`

`task->state = state;`

`set_current_state(state);`

구현은 `<linux/sched.h>` 보셈

#### Process Context
프로그램을 실행하면 user-space 에서 돈다.

SystemCall 을 하면 kernel-space로 넘어간다. 이때 kernel 에서 process context 에 접근해야 할 때, current 매크로를 통해서 접근할 수 있다.

kernel 작업을 끝내면 다시 user-space 에서 resume 한다.

kernel 에 대한 접근은 System call, exception handler 제공하는 interface 로 한다.

#### The Process Family Tree
모든 프로세스의 최초 조상은 _init_ process (pid is 1). 

kernel 은 부팅이 끝나면 마지막에 이 _init_ process 를 실행시킨다.

_init_ process 는 _initscripts_ 를 읽는다.

모든 프로세스는 하나의 parent 를 가짐.
 * task_struct 안에는 task_struct type의 parent 가 있음

`struct task_struct *my_parent = current->parent; `

모든 프로세스는 0개 또는 여러개의 children 을 가짐
    
같은 프로세스를 parent 로 가지는 프로세스들은 _siblings_.

예제1 : sibling
```c
struct task_struct *task;
struct list_head *list;

list_for_each(list, &current->children){
    task = list_entry(list, struct task_struct, sibling);
    /* task now points to one of current's children */
}
```

예제2 : init process 찾아가기
```c
struct task_struct *task;
for(task = current; task != &init_task; task = task->parent);
/* task now points to init */
```

예제3 :  모든 process 돌기
 * **Q: 그런데 이럴 일이 있나?**
```c
list_entry(task->tasks.next, struct task_struct, tasks);
list_entry(task->tasks.prev, struct task_struct, tasks);
```
아래 매크로와 같다.
```c
next_task(task)
prev_task(task)
```

예제4 : 이건 왜 있는거지?ㅋ
```c
struct task_struct *task;

for_each_process(task){
    printk("%s[%d]\n", task->comm, task->pid);
    /* task 이름[pid 번호] */
}
```

### Process Creation
Process creation in Unix is a _spawn_ mechanism
 1. fork()
    * creates a child process that is a copy of the current task
    * parent process 와 다른점
        * pid
        * 특정 resources and statistics 
            * pending signals
 2. exec()
    * load a new executable into the address space and begins executing it.
    
#### Copy-on-Write
fork()
 * parent 에 있는 모든 resource 가 복제됨
 * 그런데 너무 비효율적. 그래서 리눅스에서 fork() 는 _copy-on-write(COW)_ pages 를 사용함.
 * overhead 는 parent 의 page tables 를 duplicate 하는 정도만 발생.
 
COW(copy-on-write)
 * delay or altogether prevent copying of the data
    * parent process 의 address space 를 복제X. parent 와 child 가 single copy 를 공유함.(read-only)
    * 해당 데이터를 write 하겠다고 marking 되면 그때 duplicate 가 일어나서 각 프로세스가 unique copy 를 가짐.

Unix 의 기본 철학은 quick process execution.

#### Forking
Linux 의 fork() 는 clone() system call 로 구현함. 어떤 resource 를 parent 와 child 가 share 할 지 flag 로 넘김.(flag 설명은 [The Linux Implementation of Theads](#the-linux-implementation-of-theads) 섹션)
 * fork(), vfork(), __clone() 모두 내부적으로 clone() 콜함.
    * clone() 은 do_fork()를 콜함. `<kernel/fork.c>`
        * do_fork() 는 copy_process() 를 콜하고, 프로세스가 시작됨.
        
copy_process()
 1. dup_task_struct() 를 콜함
    * create new kernel stack, _thread_info_ structure, _task_struct_
    * 이 시점에 child 와 parent 의 process descriptor 는 같다.
 2. child 가 OS 의 current user 의 리소스제한을 넘지 않는지 체크
 3. differentiate from its parent
    * process descriptor 의 멤버들을 clear or set to initial value
    * inherit 안되는 애들은 보통 통계정보
    * _task_struct_ 의 대부분 정보는 바뀌지 않음
 4. child 의 state 를 TASK_UNINTERRUPTIBILE 로 바꿈. not yet run.
 5. copy_flags() 콜함
    * update the _flags_ member of _task_struct_.
    * PF_SUPERPRIV flag is cleared. (task 를 super user 가 소유권 가지는지 가리키는 거)
    * PF_FORKNOEXEC flag is set.
 6. alloc_pid() 콜함
 7. clone()에 던진 flag 에 따라서 duplicate / share 를 결정
    * openfile
    * filesystem info
    * signal handlers
    * process address space
    * namespace
 8. copy_process() cleans up, return to the caller a pointer to the new child.
 
copy_process() 가 성공적으로 child 를 리턴하면 do_fork() 에서 child 를 깨우고 run 시킴.
 * Deliberately, the kernel runs the child process first.
    * **Q : 이 말은 run 부터 하고 return 한다는 건가?**

#### vfork()
fork() 랑 효과는 같음. 대신 parent 의 page table 이 copy 되지 않음.

대신 parent address space 를 쓰는 thread 를 하나 띄움. 그리고 parent 는 child 가 exec() 또는 exits 할때 까지 block 됨.
 * 대신 parent address space 에 write 는 못함.

fork() 와의 비교해서 장점은 parent 의 page table 을 copy 하지 않는 것 뿐.
 * page table 또한 COW 가 적용되면 vfork() 를 쓸 이유는 전혀 없어짐.
    * **Q : 3.x 대 커널은 어떻게 구현되어있지?**
    
vfork() 의 동작. (until kernel 2.2)
 0. 내부적으로 clone() system call 에 flag 를 넣도록 구현되어있음.
 1. In _copy_process()_, the _task_struct_ member _vfork_done_ is set to NULL.
 2. In _do_fork()_, if the special flag was given, _vfork_done_ is pointed at a specific address.
 3. After the child is first run, the parent - instead of returning - waits for the child to signal it through the vfork_done pointer.
    * **Q : 그럼 spin lock 으로 기다리나?**
 4. In the _mm_release()_ function, which is used when a task exits a memory address space, _vfork_done_ is checked to see whether it is NULL. If it is not, the parent is signaled.
 5. Back in do_fork(), the parent wakes up and returns.
 

### The Linux Implementation of Theads
Thread enable _concurrent programming_ and, on multiple processor systems, true parallelism.

Linux implements all threads as standard processes.
 * 다른 프로세스와 자원을 공유하는 프로세스 일 뿐.
 * Each thread has a unique _task_struct_.
 * MS, Solaris 는 lightweight process 로 커널이 별도로 다룸.

#### Creating Threads
thread 를 만들때 불리는 clone
 * `clone(CLONE_VM | CLONE_FS | CLONE_FILES | CLONE_SIGHAND, 0);`
 
일반 fork()
 *  `clone(SIGCHLD, 0);`
 
일반 vfork()
 * `clone(CLONE_VFORK | CLONE_VM | SIGCHLD, 0);`
 
#### Kernel Threads
kernel 이 백그라운드 작업하기 위해 도는 스레드
 * normal processes 와의 차이점
    * do not have an address space
        * mm pointer is NULL.
    * operate only in kernel-space and do not context switch into user-space.
 * flush task, ksoftirqd task 도 kernel thread 를 delegates 함.
 * `ps -ef` 명령어로 커널 스레드 확인할 수 있어  
 * new kernel thread : _kthreadd_

The interface _kthreadd_ in `<linux/kthread.h>`
 *  `struct task_struct *kthread_create(int (*threadfn)(void *data), void *data, const char namefmt[], ...)`
 * 이 내부에서 clone 이 불려서 new task 만듬 
 * 새로 만들어진 프로세스는 _threadfn_ 함수를 실행시킴.
 * namefmt 는 프로세스 실행시 넘겨줄 args
 * thread is created, but unrunnable.
 * `wake_up_process()` 를 해야함 
 * `kthread_run()` : create thread & make runnable
    * `struct task_struct *kthread_run(int (*threadfn)(void *data), void *data, const char namefmt[], ...)`

```c
#define kthread_run(threadfn, data, namefmt, ...)
({
    struct task_struct *k;
    
    k=kthread_create(threadfn, data, namefmt, ## __VA_ARGS__);
    if(!IS_ERR(k))
        wake_up_process(k);
    k;
})
```

이렇게 실행된 스레드는 do_exit()를 내부에서 부르던가, 다른 곳에서 `kthread_stop()` 을 부르면 끝남
 * `int kthread_stop(struct task_struct *k)` 
 
### Process Termination
종료는 `exit()` 시스템콜
 * C 프로그램의 경우 main 함수의 return 이후에 `exit()` 가 불리게 되어있다.
 
또는 process 가 handle, ignore 할 수 없는 signal 이나 exception 을 받은 경우.

`kernel/exit.c` 에 정의된 `do_exit()`의 동작
 1. _task_struct_ 의 PF_EXITING 플래그를 세팅한다.
 2. `del_timer_sync()` 를 콜해서 kernel timer 를 지운다.
 3. BSD process accounting 이 가능하면, `acc_update_integrals()` 를 콜해서 accounting info 를 쓴다.
 4. `exit_mm()` 을 콜해서 mm_struct 를 release 한다. 이 address space 를 다른 프로세스에서 사용하지 않으면 kernel 이 해당 공간을 destroy 함.
 5. `exit_sem()` 을 콜함. 해당 프로세스가 IPC semaphore 에 queueing 되어있다면 dequeue 됨.
 6. `exit_files()`, `exit_fs()` 를 콜해서 fd 나 filesystem data 에 관련된 카운팅을 감소시킴.
 7. `task_struct` 에 있는 _exit_code_ 값을 세팅함 
 8. `exit_notify()` 를 통해 parent 에 signal 을 보냄.
 9. `schedule()` 을 콜해서 새로운 프로세스로 switching 함. `do_exit()` 는 마지막이니까 리턴될 수가 없자나.
 
다 수행되고 나면 process 는 _EXIT_ZOMBIE_ 상태가 되고. kernel stack 만 잡고있음 이때 parent process 가 커널에다가 알려주면 이때 나머지 자원이 free 됨. 

#### Removing the Process Descriptor
`do_exit()` 가 끝나도 종료된 프로세스의 process descriptor 는 존재함. (zombie and unrunnable)
 * 그래서 종료되도 child process info 를 가져올 수 있음.
 * process descriptor 정리하는 작업은 프로세스 종료와 별도로 해야함.
    * 이게 `release_task()`
    
`release_task()` 의 동작
 1. `__exit_signal()` -> `__unhash_process()` -> `detach_pid()`
    * 프로세스를 pidhash 와 task list 에서 지움.
 2. `__exit_signal()` release any resources and finalize statistics and bookkeeping.
 3. 해당 task 가 특정 스레드그룹의 마지막 멤버라면 (the reader is a zombie) zombie reader's parent 에게 noti 함.
 4. `release_task()` -> `put_task_struct()` 
    * free pages containing process's kernel stack and _thread_info_ structure,
    * deallocate the slab cache containing the _task_struct_.
    
#### The Dilemma of the Parentless Task
parent 가 먼저 없어지면 child process 를 정리해줄 놈이 없어져서 child process 는 종료 후에 zombie 가 됨.
 * reparent 해야함.
 
reparent 방법
 * 같은 스레드그룹의 다른 프로세스에게 reparent
    * 실패하면 init process 에게.
 * `do_exit()` -> `exit_notify()` -> `forget_original_parent()` -> `find_new_reaper()`
 
`find_new_reaper()`구현
```c
static struct task_struct *find_new_reaper(struct task_struct *father)
{
    struct pid_namespace *pid_ns = task_active_pid_ns(father);
    struct task_struct *thread;
    
    thread = father;
    while_each_thread(father, thread){ //thread group에서 찾기
        if(thread->flag & PF_EXITING)
            continue;
        if(unlikely(pid_ns->child_reaper == father))
            pid_ns->child_reaper = thread;
        return thread;
    }
    
    if(unlikely(pid_ns->child_reaper == father)) { //init process 를 parent로
        write_unlock_irq(&tasklist_lock);
        if(unlikely(pid_ns == &init_pid_ns))
            panic("Attempted to kill init!");
        
        zap_pid_ns_processes(pid_ns);
        write_lock_irq(&tasklist_lock);
        
        pid_ns->child_reaper = init_pid_ns.child_reaper;
    }
    return pid_ns->child_reaper;
}

```

reparent 할 새로운 parent 를 찾은 뒤에 reparent 과정
```c
reaper = find_new_reapser(father);
list_for_each_entry_safe(p, n, &father->children, sibling){
    p->real_parent = reaper;
    if(p->parent == father){
        BUG_ON(p->ptrace);
        p->parent = p->real_parent;
    }
    reparent_thread(p, father);
}
```

task 가 _ptraced_ 되면 잠시 debugging process 로 reparent 함.

reparenting 을 통해서 zombie 될 일 없음. init process 는 내부적으로 wait() 을 주기적으로 불러서 zombie process 들을 정리해줌.

### Conclusion

 