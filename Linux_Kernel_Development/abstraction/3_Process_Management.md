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