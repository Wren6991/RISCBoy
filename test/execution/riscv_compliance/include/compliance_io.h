#ifndef _COMPLIANCE_IO_H_
#define _COMPLIANCE_IO_H_

#define RVTEST_IO_INIT
#define RVTEST_IO_CHECK()

// Put this info into a label name so that it can be seen in the disassembly (holy hack batman)
#ifdef ASSERT_WITH_LABELS
#define LABEL_ASSERT_(reg, val, line) assert_ ## reg ## _ ## val ## _l ## line:
#define LABEL_ASSERT(reg, val, line) LABEL_ASSERT_(reg, val, line)
#define RVTEST_IO_ASSERT_GPR_EQ(reg, val) LABEL_ASSERT(reg, val, __LINE__) nop
#else
#define RVTEST_IO_ASSERT_GPR_EQ(reg, val)
#endif

#define RVTEST_IO_WRITE_STR(s)

#endif // _COMPLIANCE_IO_H_