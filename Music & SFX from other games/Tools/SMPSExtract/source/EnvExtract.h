#ifndef __ENVEXTRACT_H__
#define __ENVEXTRACT_H__

#include "stdtype.h"

#define ENVPTR_MASK	0x01
#define ENVPTR_68K	0x00
#define ENVPTR_Z80	0x01

#define ENVPTR_RAM	0x08

#define ENVMODE_MOD	0x00
#define ENVMODE_VOL	0x10

void ExtractEnvelopes(UINT8 ModePtr, UINT32 PtrList);

#endif	// __ENVEXTRACT_H__
