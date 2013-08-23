; Test how we handle eliding (pointer) bitcast instructions.
; TODO(kschimpf) Expand these tests as further CL's are added for issue 3544.

; RUN: llvm-as < %s | pnacl-freeze --pnacl-version=1 \
; RUN:              | pnacl-bcanalyzer -dump-records \
; RUN:              | FileCheck %s -check-prefix=PF1

; RUN: llvm-as < %s | pnacl-freeze --pnacl-version=1 | pnacl-thaw \
; RUN:              | llvm-dis - | FileCheck %s -check-prefix=TD1

; RUN: llvm-as < %s | pnacl-freeze --pnacl-version=2 \
; RUN:              | pnacl-bcanalyzer -dump-records \
; RUN:              | FileCheck %s -check-prefix=PF2

; RUN: llvm-as < %s | pnacl-freeze --pnacl-version=2 | pnacl-thaw \
; RUN:              | llvm-dis - | FileCheck %s -check-prefix=TD2

; ------------------------------------------------------

@bytes = internal global [7 x i8] c"abcdefg"

; Test that we elide the simple case of global.
define void @SimpleLoad() {
  %1 = bitcast [7 x i8]* @bytes to i32*
  %2 = load i32* %1, align 4
  ret void
}

; TD1:      define void @SimpleLoad() {
; TD1-NEXT:   %1 = bitcast [7 x i8]* @bytes to i32*
; TD1-NEXT:   %2 = load i32* %1, align 4
; TD1-NEXT:   ret void
; TD1-NEXT: }

; PF1:       <FUNCTION_BLOCK>
; PF1-NEXT:    <DECLAREBLOCKS op0=1/>
; PF1-NEXT:    <INST_CAST op0=1 op1=1 op2=11/>
; PF1-NEXT:    <INST_LOAD op0=1 op1=3 op2=0/>
; PF1-NEXT:    <INST_RET/>
; PF1-NEXT:  </FUNCTION_BLOCK>

; TD2:      define void @SimpleLoad() {
; TD2-NEXT:   %1 = bitcast [7 x i8]* @bytes to i32*
; TD2-NEXT:   %2 = load i32* %1, align 4
; TD2-NEXT:   ret void
; TD2-NEXT: }

; PF2:       <FUNCTION_BLOCK>
; PF2-NEXT:    <DECLAREBLOCKS op0=1/>
; PF2-NEXT:    <INST_LOAD op0=1 op1=3 op2=0/>
; PF2-NEXT:    <INST_RET/>
; PF2-NEXT:  </FUNCTION_BLOCK>

; Test that we elide the simple case of an alloca.
define void @SimpleLoadAlloca() {
  %1 = alloca i8, i32 4, align 4
  %2 = bitcast i8* %1 to i32*
  %3 = load i32* %2, align 4
  ret void
}

; TD1:      define void @SimpleLoadAlloca() {
; TD1-NEXT:   %1 = alloca i8, i32 4, align 4
; TD1-NEXT:   %2 = bitcast i8* %1 to i32*
; TD1-NEXT:   %3 = load i32* %2, align 4
; TD1-NEXT:   ret void
; TD1-NEXT: }

; PF1:        <FUNCTION_BLOCK>
; PF1-NEXT:     <DECLAREBLOCKS op0=1/>
; PF1-NEXT:     <CONSTANTS_BLOCK
; PF1:          </CONSTANTS_BLOCK>
; PF1-NEXT:     <INST_ALLOCA op0=1 op1=3/>
; PF1-NEXT:     <INST_CAST op0=1 op1=1 op2=11/>
; PF1-NEXT:     <INST_LOAD op0=1 op1=3 op2=0/>
; PF1-NEXT:     <INST_RET/>
; PF1-NEXT:   </FUNCTION_BLOCK>

; TD2:      define void @SimpleLoadAlloca() {
; TD2-NEXT:   %1 = alloca i8, i32 4, align 4
; TD2-NEXT:   %2 = bitcast i8* %1 to i32*
; TD2-NEXT:   %3 = load i32* %2, align 4
; TD2-NEXT:   ret void
; TD2-NEXT: }

; PF2:        <FUNCTION_BLOCK>
; PF2-NEXT:     <DECLAREBLOCKS op0=1/>
; PF2-NEXT:     <CONSTANTS_BLOCK
; PF2:          </CONSTANTS_BLOCK>
; PF2-NEXT:     <INST_ALLOCA op0=1 op1=3/>
; PF2-NEXT:     <INST_LOAD op0=1 op1=3 op2=0/>
; PF2-NEXT:     <INST_RET/>
; PF2-NEXT:   </FUNCTION_BLOCK>

; Test that we don't elide an bitcast if one of its uses is not a load.
define i32* @NonsimpleLoad(i32 %i) {
  %1 = bitcast [7 x i8]* @bytes to i32*       
  %2 = load i32* %1, align 4
  ret i32* %1
}

; TD1:      define i32* @NonsimpleLoad(i32 %i) {
; TD1-NEXT:   %1 = bitcast [7 x i8]* @bytes to i32*
; TD1-NEXT:   %2 = load i32* %1, align 4
; TD1-NEXT:   ret i32* %1
; TD1-NEXT: }

; PF1:       <FUNCTION_BLOCK>
; PF1-NEXT:    <DECLAREBLOCKS op0=1/>
; PF1-NEXT:    <INST_CAST op0=2 op1=1 op2=11/>
; PF1-NEXT:    <INST_LOAD op0=1 op1=3 op2=0/>
; PF1-NEXT:    <INST_RET op0=2/>
; PF1:       </FUNCTION_BLOCK>

; TD2:      define i32* @NonsimpleLoad(i32 %i) {
; TD2-NEXT:   %1 = bitcast [7 x i8]* @bytes to i32*
; TD2-NEXT:   %2 = load i32* %1, align 4
; TD2-NEXT:   ret i32* %1
; TD2-NEXT: }

; PF2:       <FUNCTION_BLOCK>
; PF2-NEXT:    <DECLAREBLOCKS op0=1/>
; PF2-NEXT:    <INST_CAST op0=2 op1=1 op2=11/>
; PF2-NEXT:    <INST_LOAD op0=1 op1=3 op2=0/>
; PF2-NEXT:    <INST_RET op0=2/>
; PF2:       </FUNCTION_BLOCK>

; Test that we can handle multiple bitcasts.
define i32 @TwoLoads(i32 %i) {
  %1 = bitcast [7 x i8]* @bytes to i32*       
  %2 = load i32* %1, align 4
  %3 = bitcast [7 x i8]* @bytes to i32*       
  %4 = load i32* %3, align 4
  %5 = add i32 %2, %4
  ret i32 %5
}

; TD1:      define i32 @TwoLoads(i32 %i) {
; TD1-NEXT:   %1 = bitcast [7 x i8]* @bytes to i32*
; TD1-NEXT:   %2 = load i32* %1, align 4
; TD1-NEXT:   %3 = bitcast [7 x i8]* @bytes to i32*
; TD1-NEXT:   %4 = load i32* %3, align 4
; TD1-NEXT:   %5 = add i32 %2, %4
; TD1-NEXT:   ret i32 %5
; TD1-NEXT: }

; PF1:       <FUNCTION_BLOCK>
; PF1-NEXT:    <DECLAREBLOCKS op0=1/>
; PF1-NEXT:    <INST_CAST op0=2 op1=1 op2=11/>
; PF1-NEXT:    <INST_LOAD op0=1 op1=3 op2=0/>
; PF1-NEXT:    <INST_CAST op0=4 op1=1 op2=11/>
; PF1-NEXT:    <INST_LOAD op0=1 op1=3 op2=0/>
; PF1-NEXT:    <INST_BINOP op0=3 op1=1 op2=0/>
; PF1-NEXT:    <INST_RET op0=1/>
; PF1:       </FUNCTION_BLOCK>

; TD2:      define i32 @TwoLoads(i32 %i) {
; TD2-NEXT:   %1 = bitcast [7 x i8]* @bytes to i32*
; TD2-NEXT:   %2 = load i32* %1, align 4
; TD2-NEXT:   %3 = bitcast [7 x i8]* @bytes to i32*
; TD2-NEXT:   %4 = load i32* %3, align 4
; TD2-NEXT:   %5 = add i32 %2, %4
; TD2-NEXT:   ret i32 %5
; TD2-NEXT: }

; PF2:       <FUNCTION_BLOCK>
; PF2-NEXT:    <DECLAREBLOCKS op0=1/>
; PF2-NEXT:    <INST_LOAD op0=2 op1=3 op2=0/>
; PF2-NEXT:    <INST_LOAD op0=3 op1=3 op2=0/>
; PF2-NEXT:    <INST_BINOP op0=2 op1=1 op2=0/>
; PF2-NEXT:    <INST_RET op0=1/>
; PF2:       </FUNCTION_BLOCK>

; Test how we duplicate bitcasts, even if optimized in the input file.
define i32 @TwoLoadOpt(i32 %i) {
  %1 = bitcast [7 x i8]* @bytes to i32*       
  %2 = load i32* %1, align 4
  %3 = load i32* %1, align 4
  %4 = add i32 %2, %3
  ret i32 %4
}

; TD1:      define i32 @TwoLoadOpt(i32 %i) {
; TD1-NEXT:   %1 = bitcast [7 x i8]* @bytes to i32*
; TD1-NEXT:   %2 = load i32* %1, align 4
; TD1-NEXT:   %3 = load i32* %1, align 4
; TD1-NEXT:   %4 = add i32 %2, %3
; TD1-NEXT:   ret i32 %4
; TD1-NEXT: }

; PF1:       <FUNCTION_BLOCK>
; PF1-NEXT:    <DECLAREBLOCKS op0=1/>
; PF1-NEXT:    <INST_CAST op0=2 op1=1 op2=11/>
; PF1-NEXT:    <INST_LOAD op0=1 op1=3 op2=0/>
; PF1-NEXT:    <INST_LOAD op0=2 op1=3 op2=0/>
; PF1-NEXT:    <INST_BINOP op0=2 op1=1 op2=0/>
; PF1-NEXT:    <INST_RET op0=1/>
; PF1:       </FUNCTION_BLOCK>

; TD2:      define i32 @TwoLoadOpt(i32 %i) {
; TD2-NEXT:   %1 = bitcast [7 x i8]* @bytes to i32*
; TD2-NEXT:   %2 = load i32* %1, align 4
; TD2-NEXT:   %3 = bitcast [7 x i8]* @bytes to i32*
; TD2-NEXT:   %4 = load i32* %3, align 4
; TD2-NEXT:   %5 = add i32 %2, %4
; TD2-NEXT:   ret i32 %5
; TD2-NEXT: }

; PF2:       <FUNCTION_BLOCK>
; PF2-NEXT:    <DECLAREBLOCKS op0=1/>
; PF2-NEXT:    <INST_LOAD op0=2 op1=3 op2=0/>
; PF2-NEXT:    <INST_LOAD op0=3 op1=3 op2=0/>
; PF2-NEXT:    <INST_BINOP op0=2 op1=1 op2=0/>
; PF2-NEXT:    <INST_RET op0=1/>
; PF2:       </FUNCTION_BLOCK>

; Test that we elide the simple case of bitcast for a store.
define void @SimpleStore(i32 %i) {
  %1 = bitcast [7 x i8]* @bytes to i32*
  store i32 %i, i32* %1, align 4
  ret void
}

; TD1:      define void @SimpleStore(i32 %i) {
; TD1-NEXT:   %1 = bitcast [7 x i8]* @bytes to i32*
; TD1-NEXT:   store i32 %i, i32* %1, align 4
; TD1-NEXT:   ret void
; TD1-NEXT: }

; PF1:        <FUNCTION_BLOCK>
; PF1-NEXT:     <DECLAREBLOCKS op0=1/>
; PF1-NEXT:     <INST_CAST op0=2 op1=1 op2=11/>
; PF1-NEXT:     <INST_STORE op0=1 op1=2 op2=3 op3=0/>
; PF1-NEXT:     <INST_RET/>
; PF1:        </FUNCTION_BLOCK>

; TD2:      define void @SimpleStore(i32 %i) {
; TD2-NEXT:   %1 = bitcast [7 x i8]* @bytes to i32*
; TD2-NEXT:   store i32 %i, i32* %1, align 4
; TD2-NEXT:   ret void
; TD2-NEXT: }

; PF2:        <FUNCTION_BLOCK>
; PF2-NEXT:     <DECLAREBLOCKS op0=1/>
; PF2-NEXT:     <INST_STORE op0=2 op1=1 op2=3/>
; PF2-NEXT:     <INST_RET/>
; PF2:        </FUNCTION_BLOCK>