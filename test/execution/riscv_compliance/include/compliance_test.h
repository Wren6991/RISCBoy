#ifndef _COMPLIANCE_TEST_H_
#define _COMPLIANCE_TEST_H_

#define RV_COMPLIANCE_RV32M

#define RV_COMPLIANCE_CODE_BEGIN                                              \
        .section .text.init;                                                  \
        .align  4;                                                            \
        .globl _start;                                                        \
        _start:                                                               \

#define RV_COMPLIANCE_CODE_END                                                \
        .align 4;                                                             \
        .global _rv_etext;                                                    \
        _rv_etext:                                                            \

#define RV_COMPLIANCE_HALT j .

#define RV_COMPLIANCE_DATA_BEGIN                                              \
        .section .testdata;                                                   \
        .align 4                                                              \

#define RV_COMPLIANCE_DATA_END

#endif // _COMPLIANCE_TEST_H_