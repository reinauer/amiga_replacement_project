# Amiga Bus Timing

'''

Amiga chipset operates with four states defined by the levels of the C1 (CCK) and C3 (CCKQ) signals. 

 C C    
 3 1
 ---
 1 0
 0 0    RGA Volatile
 0 1    DATA Valid
 1 1    Data Valid

               Each Line is one CCK
               
WHO   DDF           RGA DV? BPL               Disp    RGA    BPL              Disp
Chip  3F    CCK+     X   -   1  LATCH-a0       -       X     1  LATCH-a0      -                           
 "          CCKQ+    -   -   -  SHIFT-a1       -       -     -                -                         
 "          CCK-     -   Y   -  SHIFT-a2       -       -     -  SHIFT-a1      -                                  
 "          CCKQ-    -   Y   -  SHIFT-a3       -       -     -                -                         
CPU   40    CCK+     X   -   4  SHIFT-a4       -       X     -  SHIFT-a2      -                                  
 "          CCKQ+    -   -   -  SHIFT-a5       -       -     -                -                         
 "          CCK-     -   Y   -  SHIFT-a6       -       -     -  SHIFT-a3      -                                  
 "          CCKQ-    -   Y   -  SHIFT-a7       -       -     -                -                         
Chip  41    CCK+     X   -   2  SHIFT-a8       -       X     4  SHIFT-a4      -                                  
 "          CCKQ+    -   -   -  SHIFT-a9       -       -     -                -                         
 "          CCK-     -   Y   -  SHIFT-a10      -       -     -  SHIFT-a5      -                                  
 "          CCKQ-    -   Y   -  SHIFT-a11      -       -     -                -                         
CPU   42    CCK+     X   -   3  SHIFT-a12      -       X     6  SHIFT-a6      -                                  
 "          CCKQ+    -   -   -  SHIFT-a13      -       -     -                -                         
 "          CCK-     -   Y   -  SHIFT-a14      -       -     -  SHIFT-a7      -                                  
 "          CCKQ-    -   Y   -  SHIFT-a15      -       -     -                -                         
Chip  43    CCK+     X   -   1  LATCH-b0       -       X     2  SHIFT-a8      -                                  
 "          CCKQ+    -   -   -  SHIFT-b1       -       -     -                -                         
 "          CCK-     -   Y   -  SHIFT-b2       -       -     -  SHIFT-a9      -                                  
 "          CCKQ-    -   Y   -  SHIFT-b3       -       -     -                -                         
CPU   44    CCK+     X   -   4  SHIFT-b4       -       X     -  SHIFT-a10     -                                  
 "          CCKQ+    -   -   -  SHIFT-b5       -       -     -                -                         
 "          CCK-     -   Y   -  SHIFT-b6       -       -     -  SHIFT-a11     -                                  
 "          CCKQ-    -   Y   -  SHIFT-b7       -       -     -                -                         
Chip  45    CCK+     X   -   2  SHIFT-b8       a0      X     3  SHIFT-a12     a0                                  
 "          CCKQ+    -   -   -  SHIFT-b9       a1      -     -                a0                           
 "          CCK-     -   Y   -  SHIFT-b10      a2      -     -  SHIFT-a13     a1                                  
 "          CCKQ-    -   Y   -  SHIFT-b11      a3      -     -                a1                           
CPU   46    CCK+     X   -   3  SHIFT-b12      a4      X     5  SHIFT-a14     a2                                  
 "          CCKQ+    -   -   -  SHIFT-b13      a5      -     -                a2                           
 "          CCK-     -   Y   -  SHIFT-b14      a6      -     -  SHIFT-a15     a3                                  
 "          CCKQ-    -   Y   -  SHIFT-b15      a7      -     -                a3                           
Chip  47    CCK+     X   -   1  LATCH-c0       a8      X     1  LATCH-b0      a4                            
 "          CCKQ+    -   -   -  SHIFT-c1       a9      -     -                a4             
 "          CCK-     -   Y   -  SHIFT-c2       a10     -     -  SHIFT-b1      a5                                       
 "          CCKQ-    -   Y   -  SHIFT-c3       a11    -      -                a5       
      48...

'''