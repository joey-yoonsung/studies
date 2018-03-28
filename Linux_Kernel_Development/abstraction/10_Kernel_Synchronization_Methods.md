# 10. Kernel Synchronization Methods
This chapter discusses Linux kerenel's synchronization methods, interfaces, behavior and use.

## Atomic Operations
atomic operation : single individual and uninterruptable step.
 * 예제와 같은 race 가 애초에 발생할 수 없음!

two interfaces for atomic operation
 * operates on integer
 * operates on individual bits

architecture 에 따라 atomic operation instruction 의 동작이 조금 다름.
 * simple arithmetic operation
 * lock the memory bus for single operation (direct atomic operation instruction 이 힘든경우)


### Atomic Integer Operations
`atomic_t` type 을 쓴다.

**atomic function 은 atomic_t 만 받을 수 있다.** (그냥 int 는 안됨)
 1. atomic operation 은 이 타입으로만 사용한다는 게 보장. (역으로 다른 타입으로 사용할 수 없다는 걸 보장)
 2. ensure compiler does not optimize access to the value - 즉, 정확한 메모리 주소를 받는다!
 3. can hide any architecture-specific differences in its implementation.

```c
typedef struct{
    volatile int counter;
}atomic_t
```

**SPARC architecture 의 제약사항**
 * aotmic_t 가 아래 8 bit 를 lock 을 잡음.
 * 그래서 singed 24bit integer 범위밖에 못씀.
 * 32bit 범위 다 쓸 수 있는 핵이 생겨서 **지금은 상관 없음.**


**기본적인 atomic_t 지원 function 및 사용예제**
```c
atomic_t v;                     //define
atomic_t u = ATOMIC_INIT(0);    //define and initialize

atomic_set(&v, 4);      // v = 4
atomic_add(2, &v);      // v = v + 2 = 6
atomic_inc(&v);         // v++; = 7
atomic_dec(&v);         // v--; = 6
```

int 로 받고싶으면 `atomic_read(&v)` 하세용.

`int atomic_dec_and_test(atomic_t *v)`
 * v-- 한 결과가 0 이면 true, 아니면 false.

Table 10.1 에 atomic_t operation methods

**atomic operation are typically implemented as inline functions with inline assembly.**
inline 인 이 function 은 just macro 이다.
```c
static inline int atomic_read(const atomic_t *v)
{
    return v->counter;
}
```

#### Atomicity Versus Ordering
 * atomocity : 하나의 instruction 에 대해서 interruption 이 없다는 것을 보장
 * ordering : 두개 이상의 instruction 의 상대적인 순서 보장.

1~2 atomic operation 이 lock mechanism 보다 낫다.
 * less overhead
 * less [cache-line thrashing](https://www.quora.com/What-is-cache-thrashing) ( [thrashing](https://en.wikipedia.org/wiki/Thrashing_(computer_science)) )

### 64-bit Atomic Operation

`atomic_t` 는 사실 `atomic32_t`임. architecture 마다 맞춰주지 않음.

64bit architecture 에서는 `atomic64_t` type 을 쓰세요!

* 구현
```c
typedef struct{
    volatile long counter;
}atomic64_t;
```

API 는 기존의 atomic 관련 함수들에서 'atomic' 글자를 atomic64 로 바꾸면 그대로 쓸 수 있음.

대부분 32-bit architecture 는 atomic64_t 를 지원하지 않는다.
 * x86_32 는 예외다.

개발자는 32-bit 인 atomic_t 를 써야한다. 두 아키텍처 모두 지원 or 64bit 전용 코드만 atomic64_t 쓰세요.


### Atomic Bitwise Operations

bit-level 에서 atomicity 지원

architecture-specific 하다.

`<asm/bitops.h>` 에 정의.

bit 자리수에 해당하는 숫자를 세팅하는 방식
 * 32-bit machine : 0~31
 * 64-bit machine : 0~63

어떤 데이터 타입이든 포인터로 쓸 수 있음. (atomic_t 일 필요 없음)
 * 그래서 api 가 parameter로 `void*` 를 받음

에제코드
```c
unsinged int word = 0;
set_bit(0, &word); // 00000000000000000000000000000001
set_bit(0, &word); // 00000000000000000000000000000011
printk("%u\n", word); // 3
clear_bit(1, &word); // 00000000000000000000000000000001
clear_bit(0, &word); // 00000000000000000000000000000000

if(test_and_set_bit(0, &word)){ // 0번째 bit를 set 하고, set 하기 이전 값을 return 한다. return 0

}
```

**test_ 가 prefix 된 형식의 API 는 read&something 라고 생각하는게 속편함**
 * atomic_t 데이터는 atomic_read API 가 존재.

nonatomic bit operation API
 * 위의 atomic bit operation API의 앞에 __(언더바 두개)를 붙여서 쓰면됨.

#### 도대체 Nonatomic bit operation 은 왜 있는거?

**이거 예제가 무슨말을 하고 싶은건지 이해가 안됨.**

`int find_first_bit(unsigned long *addr, unsigned int size)` : 해당 주소 에서 첫번째 set(1) 되어있는 bit 자리 리턴

`int find_first_zero_bit(unsigned long *addr, unsigned int size)` : 해당 주소 에서 첫번째 unset(0) 되어있는 bit 자리 리턴

race condition 없으면 nonatomic 쓰세요!


## Spin Locks
lock 을 얻을 때까지 스레드가 loop 를 돎면서 busy waiting 하는 방식.

짧은 시간을 기다릴 경우에만 쓰세요.
 * 너무 오래 기다릴 경우, cpu 가 다른 일을 할 수 있는 시간을 오래 뺏는 꼴이 됨. -> overhead
 * 오래 기다릴 것 같으면 semaphore 를 써서 해당 thread가 sleep 하게 하세요.

### Spin Lock Methods
Spin locks are architecture-dependent and implemented in aseembly.
 * `<asm/spinlock.h>` - architecture-dependent code
 * `<linux/spinlock.h>` - usable interfaces

##### 기본 API
```c
DEFINE_SPINLOCK(mr_lock);
spin_lock(&mr_lock);
/* ciritical region */
spin_unlock(&mr_lock);
```

##### critical section 을 interrupt 로부터 보호할 수 있는 spin lock

```c
DEFINE_SPINLOCK(mr_lock);
unsigned long flags;

spin_lock_irqsave(&mr_lock, flags);
/* ciritical region */
spin_unlock_irqrestore(&mr_lock, flags);
```
 * **주의** : 이 irqsave - restore 방식은 현재 interrupt 가 이미 disabled 된 상태라면 원하는 동작과 반대로 동작한다.

##### 이렇게 하면 해결할 수 있어.
```
DEFINE_SPINLOCK(mr_lock);
spin_lock_irq(&mr_lock);
/* ciritical region */
spin_unlock_irq(&mr_lock);
```
이 코드는 끝나면 무조건 interrupt enable 상태가 됨.

##### uniprocessor machine 경우는 lock 이 compile away 된다.
 * kernel preemption 을 disable / enable marker 로 동작.

##### [리눅스 스핀락 내부구현에 대한 자세한 설명](http://www.linuxinternals.org/blog/2014/05/07/spinlock-implementation-in-linux-kernel/)

#### Spin Locks Are Not Recursive!
다른 운영체제나 라이브러리 구현이랑은 다르게 spin lock 이 recursive 함수로 구현되어있지 않다.
같은 spin lock 을 hold 한 상태에서 또 하면 dead lock 이 걸린다.

#### Other Spin Lock Methods
 * `spin_lock_init()`
 * `spin_trylock()`
 * `spin_is_locked()`

#### Spin Locks and Bottom Halves
Bottom Halve 의 목적을 생각해보자!  - interrupt 처리하는데 오래 걸리는 부분을 나중에 미뤄서 처리하자!
 * Bottom Halve 도는 동안에는 preempt 가 가능하다.
    1. 그런데 bottom-half process context 사이에 데이터 공유되면?
    2. 데이터를 공유하는 interrupt 가 들어오면?
 * 따라서 여기에 적절한 lock 이 필요하다.

 * `spin_lock_bh()` : lock and disables all bottom havles
 * `spin_unlock_bh()` : unlock and enables bottom havles

 * tasklet 의 경우는 tasklet 끼리 preempt 할 일이 없기 때문에 lock 만 잡으면 됨
 * softirq 도 같은 processor 상에서는 preempt 할 일이 없기 때문에 lock 만 잡으면 됨

## Reader-Writer Spin Locks
상황
 1. list 에 update 할 때, 어떤 스레드도 read/write 를 동시에 하면 안됨.
 2. list 를 읽을 때, 여러 스레드가 읽어도 되지만, 어느 하나라도 write 하면 안됨.

**reader/writer , producer/consumer 로 나누자!**
 * Multiple reader can optain reader lock. (shared)
 * Only one writer can optain writer lock with no concurrent reader.(exclusive)
 * _shared/exclusive locks_ 또는 _concurrent/exclusive locks_ 이라고도 함

```c
DEFINE_RWLOCK(mr_rwlock);

read_lock(&mr_rwlock);
/* critical section : can only read */
read_unlock(&mr_rwlock);


write_lock(&mr_rwlock);
/* critical section : can read & write*/
write_unlock(&mr_rwlock);
```
 * 단, read_lock 을 unlock 하지 않고 이어서 write_lock 을 이어서 할 수 없다. **DEAD LOCK**
    * 같은 thread 에서 read_lock 을 또 얻는건 상관없음.
 * interrupt 에서 보호하고 싶으면 `read_lock_irqsave()` , `write_lock_irqsave()` 를 쓰세요.

**주의할 점**
 * They favor reader over writers. 일어날 상황을 잘 알고 그에 맞게 디자인해야함. 아니면 오히려 부작용이 클 수 있음
    * reader 들은 writer 가 unlock 할 때까지 읽지를 못하고
    * writer 는 모든 reader 가 unlock 할 때까지 쓰질못함.
 * **Q : 개인이 프로그램 짜면서 마주쳤던 상황에서 reader-writer lock이 적절/부적절 할 수 있는 사례?**

## Semaphores
 1. semaphore 를 요청한다.
 2. 얻을 수 없다면 task 를 wait queue 에 넣고 task 를 재운다.
 3. wait queue 에 task 를 넣은 processor 는 다른 task 를 실행한다.
 4. semaphore 를 얻을 수 있는 wait queue 에 있던 task 중 하나를 깨운다.


고려할 점
 1. lock 을 오랜시간 잡고 있는 경우.
 2. 짧은 기간 기다리는 경우는 부적절.
 3. process context 에 적합. interrup context 는 not schedulable 해서 안 됨.
 4. semaphore 를 hold 하고 있는 동안에도 sleep 할 수 있다. (다른 프로세스가 같은 semaphore 를 얻어가면)
 5. semaphore 를 hold 하는 중에 spin lock 을 돌 수 없다. spin lock 을 얻은 중에 sleep 할 수도 없다.

**semaphore versus spin lock** : not busy waiting, but more overhead.
 1. sleep 이 필요하냐? (user-space)  **semaphore**
 2. hold time 이 짧냐? **spin lock**
 3. kernel preemption 을 막을 필요가 있냐? **spin lock**

### Counting and Binary Semaphores
Holder 수를 정할 수 있다.(count) == (동시에 하나 이상 hold 할 수 있다)
 * declaration 때 정한다.
 * 이 count 가 1 일때 : _binary semaphore_ , _mutex_
 * 1 보다 클때 : _counting semaphore_
    * kernel 에선 잘 안쓰임. 웬만하면 mutex 로 쓰셈.

다익스트라 아저씨가 formalize 함 (아랜 내맘대로 pseudo code)
```c
if(count >= 0){
    aquire_lock();
    down(); //count--;
}else{
    on_wait_queue(this);
}

when(release){
    up(); //count++;
}
```

### Creating and Initializing Semaphores

```c
struct semaphore name;
sema_init(&name, count); //concurrent usage count

static DCLARE_MUTEX(name); // sema_init(&name, 1);

sema_init(sem, count); // dynamic create : pointer reference 를 넘긴다.
init_MUTEX(sem);    // API 에 일관성 없는걸로 놀라지 마세용
```

### Using Semaphores

 * `down_interruptible()` : 세마포를 못 얻으면 TASK_INTERRUPTIBLE 로 task state 를 바꾸고 sleep 한다. waiting 도중에 signal 이 오면 _EINTER_ 를 리턴함.
 * `down()` : TASK_UNINTERRUPTIBLE 로 task state 를 바꾸고 sleep 한다. semaphore 를 기다리는 프로세스가 singal 에 응답하지 않는다.
 * `down_trylock()` : blocking 없이 세마포를 얻을 수 있다. 세마포가 이미 hold 되어있으면 nonzero 를 리턴함. 0을 리턴하면 세마포를 얻은 것.
 * `up()` : release semaphore

```c
static DECLARE_MUTEX(mr_sem);

if(down_interruptible(&mr_sem)){
    /* singal 이 오면 semphore 를 못얻음 */
}
/*critical region*/
up(&mr_sem);  // release semaphore
```

## Reader-Writer Semaphores
앞의 spin lock 과 개념은 같음.

`struct rw_semaphore` type declared in `<linux/rwsem.h>`

```c
static DECLARE_RWSEM(name);  // static declare
init_rwsem(struct rw_semaphore *sem) // dynamic declare
```

usage
```c
static DECLARE_RWSEM(mr_rwsem);  // static declare
down_read(&mr_rwsem);
/* critical region : read only */
up_read(&mr_rwsem);

down_write(&mr_rwsem);
/* critical region : read and write */
up_write(&mr_rwsem);
```

위에서 설명한 try 형식 메소드도 지원 :  `down_read_trylock(struct rw_semaphore *sem)`, `down_write_trylock(struct rw_semaphore *sem)`

`downgrade_write()` : atomic 하게 이미 얻은 write_lock 을 read_lock 으로 바꿈.
 * write_lock 얻고 read_lock 얻을 생각하지 말고, write_lock 얻은 다음에 이 메소드를 부르면 됨.

## Mutexes
mutual exclusion lock - sleeping version of spin lock , simpler sleeping lock

usage
```c
DEFINE_MUTEX(name); // static
mutex_init(&mutex); // dynamic

mutex_lock(&mutex);
/* ciritical region*/
mutex_unlock(&mutex);
```

#### constraints
기존 세마포보다 stricter, narrower use case.
 1. only one task can hold the mutex at a time.
 2. lock 잡은 context 에서 unlock 해야함. - kernel / user space 사이에서 synchronization 하는 경우에 부적절
 3. no recursive use
 4. mutex 잡는 동안 프로세스가 끝날 수 없음
 5. interrupt handler 나 bottom half 에서 사용할 수 없음.(try 종류도 마찬가지)
 6. official API 로만 사용할 수 있음.

디버깅 하고 싶으면 _CONFIG_DEBUG_MUTEXES_ 커널옵션을 enable 시켜야함.

### Semaphores Versus Mutexes
위의 constraints 가 문제되지 않는다면 semaphore 보다 mutex 를 쓰세요.

### Spin Locks Versus Mutexes
 * spin lock 은 interrupt context 에서 쓸 수 있고
 * Mutex 는 sleep 할 수 있다.

#### What to use
 * Low overhead locking : **Spin Lock** (preferred)
 * Short lock hold time : **Spin Lock** (preferred)
 * Long lock hold time : **Mutex** (preferred)
 * Need to lock from interrupt context : **Spin Lock** (required)
 * Need to sleep while holding lock: **Mutex** (required)

## Completion Variables
커널에서 두개의 task 사이에서 한쪽에서 다른 한쪽으로 signal 보낼 때 쓰기 쉬운 방법.
 * 한놈이 completion variable 을 기다리고, 다른쪽에서 일이 끝나면 해당 completion variable 로 기다리는 쪽을 깨운다.
 * 예 : parent 가 child를 vfork() 하고, child 가 exec 나 exit 했을때 parent process 를 깨우면 parent process 는 fork 를 마치고 남은 작업을 진행한다.
 * `<kernel/sched.c> <kernel/fork.c>` 를 보면 사용하는거를 찾아볼 수 있음

`struct completion` type declared in `<linux/completion.h>`

```c
DECLARE_COMPLETION(mr_comp); //static
init_completion(&mr_comp); //dynamic
wait_for_completion(&mr_comp); // waits given completion variable
complete(&mr_comp); // signal any waiting tasks to wake up
```

## BKL : The Big Kernel Lock
global spin lock
 * 원래 SMP impl 을 fine-grained locking 로 쉽게 전환하기 위해 만들어짐.

특이점
 * BKL 을 잡는동안 sleep  할 수 있다. (안전하다는 건 아님, 데드락 주의!)
    * unschedule 될때 자동으로 holding 을 drop 하고, reschedule 될 때 다시 얻는다.
 * recursive lock - single process 가 여러번 lock 을 얻을 수 있음 (not dead lock)
    * `lock_kernel()` 부른 횟수 만큼 `unlock_kernel()` 을 불러줘야함.
    * `kernel_locked()` return nonzero (락 잡고있으면)
    * `<linux/smp_lock.h>
 * can use only in process context. (cannot in interrupt context)
 * kernel preemption 을 disable 함.
 * BKL 쓰는 사람이 점점 없어짐...?
    * kernel 2.0 에서 2.2 로 전환하기 쉽게하기 위해 제공 되었음.
    * data 를 보호한다기 보다 code 블럭을 보호하기 위하는 느낌적인 느낌.
        * 무엇을 보호하고 싶은건지..? 가 불분명함.

**웬만하면 쓰지마셈**
 * 근데 왜 소개?
    * 알아둘 필요가 있으니까!

## Sequential Locks
write_lock 을 요구할 때마다 sequence count 가 올라감.
read 하기 전에 sequence count 를 확인하고, 자신이 read 요청할때의 sequence count 와 같아질 때까지 기다렸다가. 같아지면 read 함.
 * read 하는동안 write 할 수는 없음.
 * 짝수 - write 하는중이 아님. (write lock 이 홀수를 만들고, lock 을 release 할 때 짝수를 만듬)

```c
seqlock_t mr_seq_lock = DEFINE_SEQLOCK(mr_seq_lock);

write_seqlock(&mr_seq_lock);
/* wirte lock 얻었당! mr_seq_lock become odd number*/
write_sequnlock(&mr_seq_lock); // mr_seq_lock become even number

// read 하는 방식에 주목
unsigned long seq;
do{
    seq = read_seqbegin(&mr_seq_lock);
    /* read here */
}while(read_seqretry(&mr_seq_lock, seq));

```

many readers & few writers 일 때, lightweight and scalable lock 으로 유용.
 * But, favor writers over readers (앞의 다른 Reader-Writer lock 들은 favor reader over writers)
 * 다른 writer 가 없는 이상 write lock 을 항상 얻을 수 있음
 * 더이상 writer 없을 때까지 reader 는 무한정 기다려야함!

Requirement
 * a lot of readers
 * few writers
 * favor writers over readers and never allow readers to starve writers.
 * data is simple. atomic data 로 만들 수 없음.

_jiffies_
 * machine 이 booting 된 후부터 clock tick 64bit number count.
 * 64 bit 를 atomic 하게 못 읽으니까 `get_jiffies_64() 는 seq lock 을 구현함.

 * 지피값 읽을 때
 ```c
 u64 get_fiffies_64(void)
 {
    unsinged long seq;
    u64 ret;

    do{
        seq = read_seqbegin(&xtime_lock);
        ret = jiffies_64;
    }while(read_seqretry(&xtime_lock, seq));
    return ret;
 }
 ```

 * 지피값 쓸 때
 ```c
 write_seqlock(&xtime_lock);
 jiffies_64 += 1;
 write_sequnlock(&xtime_lock);
 ```
 * 지피 값에 대한 자세한 내용은 Chapter11 에서...


## Preemption Disabling
kernel 의 preemption code 는 preemption 하지 말아야할 영역 표시를 위해서 spin lock 을 씀. 

concurrency 가능성이 없는 데이터(uni-processor, 또는 하나의 processor 에만 접근하는 데이터)도 역시 preemption 에 대비한 lock 은 해야함.

 * `preempt_disable()` : preempt count 를 증가시킴.
 * `preempt_enable()` : preempt count 를 감소시킴. // count 가 0 이면 reschedule 할 놈이 있는지 확인.
 * `preempt_enable_no_resched()` : preempt count 를 감소시킴. // reschedule 할 놈이 있는지 확인안함. 
 * `preempt_count()` : 현재 preempt count 를 가져옴. 0이면 preemption 할 수 있음.  

 이 preemption disabling 을 사용해서 per-processor data issue 를 해결 할 수 있다.
```c
int cpu;
cpu = get_cpu();    // disable kernel preemption and set "cpu" to the current processor
put_cpu();         // enable kernel preemption
```

## Ordering and Barriers
_barriers_ instruction 들을 이용해서 compile 때 re-ordering 되는 걸 막을 수 있어.

```c
a=1;
b=2;
```
 * 컴파일러가 컴파일할때 a, b가 서로 상관없으니까 나름대로 규칙에 따라 b 가 먼저 세팅되도록 re-ordering 할 수 있음. (static)
 * processor 는 dynamic 하게 돌면서 fetching & dispatching 하는 방식으로 re-ordering 할 수 있음. (a 랑 b 가 dependency 가 없다는 전제하에)
 
```c
a=1;
b=a;
```
 * 이런 코드는 processor 가 a 와 b 의 dependency 가 분명하기 때문에 re-ordering 안함.
 
하드웨어 차원에서도 할 수 있음
  * `rmb()` : read memory barrier 를 제공. 이 메소드 앞에 있는 load instruction 을 이 메소드 이후로 re-ordering 불가.
  * `wmb()` : write memory barrier - rmb 와 비슷 - store instruction 에 대해서 
  * `mb()` : read | write 전부.
  * `read_barrier_depends()` : read barrier 인데, 앞뒤로 dependency 가 있는 경우에만 barrier (꼭 필요한 경우에만 한다는 뜻)
  
#### 예제 1
```c
init : a = 1;, b = 2;

Thread 1        |       Thread2
a = 3;
mb();
b = 4;          |       c = b;
                        rmb();
                        d = a;
```
 * mb() 는 a와 b 가 순서대로 쓰이도록 보장.
 * rmb() 는 c가 b 를, d 가 a를 순서대로 읽도록 보장.
 * **Q : 그래도 c 가 b 를 읽을 때 2가 올지, 4가 올지는 보장이 안되는거 아닌가?**
    * d 에는 3이 들어가는 것이 확실히 보장됨.
    
#### 예제 2 
```c
init : a = 1;, b = 2;

Thread 1        |       Thread2
a = 3;
mb();
p = &a;         |       pp = p;
                        read_barrier_depends();
                        b = *pp;
```
 * read_barrier_depends() : b 가 확실히 a 값을 갖도록 보장.
    * mb() : a가 확실히 3값을 갖고 p 에 읽히도록 보장
    
UP kernel 은 only compiler barrier

SMP 용은`smp_rmb()`, `smp_wmb()`, `smp_mb()`,  `smp_read_barrier_depends()` SMP 최적화.

* barrier() : load | store 에 대해서 compiler-barrier 그런데 컴파일러 barrier 는 약해. (processor 가 re-ordering 하는거 못 막으니까)

**주의** : 대신 아키텍처나 버전에 따라서 확인하고 worst case 에 대비해서 써야함. (Intel x86 processor 는 `wmb()`가 아무것도 안함. )