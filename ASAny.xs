#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include "ASAny.h"

/* --- Variables --- */


DBISTATE_DECLARE;

MODULE = DBD::ASAny	PACKAGE = DBD::ASAny

INCLUDE: ASAny.xsi

# end of ASAny.xs
