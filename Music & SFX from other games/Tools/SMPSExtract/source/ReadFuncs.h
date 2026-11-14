#ifndef __READFUNCS_H__
#define __READFUNCS_H__

#include "stdtype.h"

INLINE UINT16 ReadBE16(const UINT8* Data);
INLINE UINT32 ReadBE32(const UINT8* Data);
INLINE UINT16 ReadLE16(const UINT8* Data);
INLINE void WriteBE32(UINT8* Data, UINT32 Value);	// slightly out of place, but I don't feel like renaming everything

void FixMarsPointer(UINT32* ROMPos);	// function from SMPSExtract.c - here for convenience


INLINE UINT16 ReadBE16(const UINT8* Data)
{
	return (Data[0x00] << 8) | (Data[0x01] << 0);
}

INLINE UINT32 ReadBE32(const UINT8* Data)
{
	return	(Data[0x00] << 24) | (Data[0x01] << 16) |
			(Data[0x02] <<  8) | (Data[0x03] <<  0);
}

INLINE UINT16 ReadLE16(const UINT8* Data)
{
	return (Data[0x01] << 8) | (Data[0x00] << 0);
}

INLINE void WriteBE16(UINT8* Data, UINT16 Value)
{
	Data[0x00] = (Value >>  8) & 0xFF;
	Data[0x01] = (Value >>  0) & 0xFF;
	
	return;
}

INLINE void WriteBE32(UINT8* Data, UINT32 Value)
{
	Data[0x00] = (Value >> 24) & 0xFF;
	Data[0x01] = (Value >> 16) & 0xFF;
	Data[0x02] = (Value >>  8) & 0xFF;
	Data[0x03] = (Value >>  0) & 0xFF;
	
	return;
}

#endif	// __READFUNCS_H__
