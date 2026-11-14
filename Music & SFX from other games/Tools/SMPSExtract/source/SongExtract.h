#ifndef __SONGEXTRACT_H__
#define __SONGEXTRACT_H__

#include "stdtype.h"

#define PTR_68K		0x00
#define PTR_Z80		0x10
#define PTR_ORNS	0x11
#define PTR_MMWW	0x01
#define PTR_SM1bM4	0x02
//#define PTR_Z80RAM	0x12
#define PTR_Z80BPTR	0x13
#define PTR_S2CDV2	0x03
#define PTR_DARWIN	0x04

void ExtractSongs(UINT8 Mode, UINT32 MusPtrList, UINT32 BankList, UINT32 BnkBase);

#endif	// __SONGEXTRACT_H__
