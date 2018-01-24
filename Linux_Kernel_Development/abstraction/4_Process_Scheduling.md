# Process Scheduling

참고할만한 자료

 1. [단순 요약](http://tturbs.blogspot.kr/2014/10/4.html)
 2. [ppt 요약](http://cslab.jbnu.ac.kr/board/bbs/board.php?bo_table=seminar&wr_id=8&page=0&page=0)
 3. [최신 리눅스 스케줄러 구조 및 역할 정리](http://jake.dothome.co.kr/scheduler/)
    * [문c 블로그](http://jake.dothome.co.kr) : IAMROOT.org 에서 활발히 활동하는 분 블로그. 커널관련 좋은 자료가 많다.
        * IAMROOT.org 커널 위주로 시스템 소프트웨어 스터디그룹. 깊이 있는 스터디가 오랫동안 활발하게 진행중임.
        
 4. [CFS scheduler 로의 발전과정을 잘 정리한 글](http://egloos.zum.com/tory45/v/5167290)
 
### O(1) 스케줄러
하나의 bit 가 하나의 priority 를 나타내는 bitmap 배열을 가진다.
 
두 개의 배열(active, expired) 을 가지고 active 에서 처리한 task 는 expired 로 이동시키고, active 의 사이즈가 0 이 되면 expired 에 있는 task 들이 다시 active 가 되어 같은 방식으로 계속 돈다.

이거 나왔을때도 센세이션이었는데 단점이 좀 있었음.

#### O(1) 스케줄러의 단점
 1. It potentially can take a long time. Worse, it scales O(n) for n tasks on the system.
 
 2. The recalculation must occur under some sort of lock protecting the task list and the individual process descriptors. This results in high lock contention.
 
 3. The nondeterminism of a randomly occurring recalculation of the timeslices is a problem with deterministic real-time programs.
  
 4. It is just gross (which is a quite legitimate reason for improving something in the Linux kernel).
 
#### [kworker](https://askubuntu.com/questions/33640/kworker-what-is-it-and-why-is-it-hogging-so-much-cpu)
 * "kworker" is a placeholder process for kernel worker threads, which perform most of the actual processing for the kernel, especially in cases where there are interrupts, timers, I/O, etc. These typically correspond to the vast majority of any allocated "system" time to running processes. It is not something that can be safely removed from the system in any way, and is completely unrelated to nepomuk or KDE (except in that these programs may make system calls, which may require the kernel to do something).
 * kworker means a Linux kernel process doing "work" (processing system calls). You can have several of them in your process list: kworker/0:1 is the one on your first CPU core, kworker/1:1 the one on your second etc..

#### RB(Red-Black) Tree
 * insert, remove, find 에 대해서 모두 O(_log n_) 을 보장함.
 * 어떤 root -> leaf 경로가 어떤 경로이건 black node 개수가 같음을 보장.
 * 최장 경로와 최단 경로의 depth 가 두 배 이상이 될 수 없다.
 
 
**Q : 어느정도 깊이로 공부해야할지..?**
 * 모르겠다. 웹에서 검색하면 나름의 방식대로 깊이 분석한 글들도 있는데 제각기 커널 버전은 다르다. 
 * 현재는 커널 4.x 버전인데 4.x 분석한 글은 찾아보기 힘들다.(한국은 문c 블로그가 유일)
 * 현재 버전으로 분석하자니 기존의 구조나 방법과 달라진점에 대해서 track 하기 어려워서 너무 막막하다.
 * 흠..