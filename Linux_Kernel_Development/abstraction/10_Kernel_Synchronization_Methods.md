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

 * `down_interruptible()` : 세마포를 못 얻으면 TASK_INTERRUPTIBLE 로 task state 를 바꾸고 sleep 한다. waiting 도중에 signal 이 오면 
 * `down()` :

