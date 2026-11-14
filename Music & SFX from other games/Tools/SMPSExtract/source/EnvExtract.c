// SMPS Envelope Extractor
// -----------------------
// Written by Valley Bell

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <memory.h>
#include <string.h>
#include "stdtype.h"

#include "ReadFuncs.h"
#include "EnvExtract.h"

typedef struct envelope_data
{
	char Name[0x10];
	UINT8 DataLen;
	const UINT8* Data;
} ENV_DATA;
typedef struct envelope_file
{
	UINT8 EnvCount;
	UINT8 EnvAlloc;
	ENV_DATA* Envelope;
} ENV_FILE;

static const char* SIG_ENV = "LST_ENV";

static void SaveEnvelopeFile(const char* FileName, const ENV_FILE* EnvData);
static UINT32 GetNextAddr(UINT16 PtrCnt, const UINT32* PtrList, UINT32 MinAddr);

extern UINT32 ROMLength;
extern UINT8* ROMData;
extern UINT16 RAMSize;
extern UINT8* RAMData;

extern UINT8 ReadOnlyMode;

void ExtractEnvelopes(UINT8 ModePtr, UINT32 PtrList)
{
	const char* ENV_NAMEBASE;
	UINT32 MemSize;
	const UINT8* MemData;
	ENV_FILE EnvData;
	UINT32* OfsList;
	UINT8 CurEnv;
	UINT8 RemEnvs;
	UINT8 TempByt;
	UINT32 MaxPos;
	UINT32 CurPos;
	UINT32 TempPos;
	
	EnvData.EnvCount = 0x00;
	EnvData.EnvAlloc = 0x80;
	EnvData.Envelope = (ENV_DATA*)malloc(EnvData.EnvAlloc * sizeof(ENV_DATA));
	OfsList = (UINT32*)malloc(EnvData.EnvAlloc * sizeof(UINT32));
	
	if (ModePtr & ENVMODE_VOL)
		ENV_NAMEBASE = "PSG";
	else
		ENV_NAMEBASE = "Mod";
	if (ModePtr & ENVPTR_RAM)
	{
		MemSize = RAMSize;
		MemData = RAMData;
	}
	else
	{
		MemSize = ROMLength;
		MemData = ROMData;
	}
	
	MaxPos = MemSize;
	CurPos = PtrList;
	if ((ModePtr & ENVPTR_MASK) == ENVPTR_68K)
	{
		for (CurEnv = 0x00; CurEnv < EnvData.EnvAlloc; CurEnv ++, CurPos += 0x04)
		{
			if (CurPos >= MaxPos)
				break;
			
			TempPos = ReadBE32(&MemData[CurPos]);
			FixMarsPointer(&TempPos);
			if (TempPos < 0x1000 || TempPos >= MemSize)
				break;
			
			if (TempPos < MaxPos)
				MaxPos = TempPos;
			OfsList[CurEnv] = TempPos;
		}
	}
	else
	{
		for (CurEnv = 0x00; CurEnv < EnvData.EnvAlloc; CurEnv ++, CurPos += 0x02)
		{
			if (CurPos >= MaxPos)
				break;
			
			TempPos = ReadLE16(&MemData[CurPos]);
			if (TempPos & 0x8000)
			{
				TempPos &= 0x7FFF;
				TempPos |= (PtrList & 0xFF8000);
			}
			if (TempPos >= MemSize)
				break;
			
			if (TempPos < MaxPos)
				MaxPos = TempPos;
			OfsList[CurEnv] = TempPos;
		}
	}
	EnvData.EnvCount = CurEnv;
	
	for (CurEnv = 0x00; CurEnv < EnvData.EnvCount; CurEnv ++)
	{
		CurPos = OfsList[CurEnv];
		EnvData.Envelope[CurEnv].Data = &MemData[CurPos];
		
		TempPos = GetNextAddr(EnvData.EnvCount, OfsList, CurPos);
		if (TempPos <= MemSize)
		{
			TempPos -= CurPos;
		}
		else
		{
			while(CurPos < MemSize)
			{
				TempByt = MemData[CurPos];
				CurPos ++;
				if (TempByt >= 0x80 && TempByt <= 0x85)
				{
					if (TempByt == 0x82 || TempByt == 0x84 || TempByt == 0x85)
						CurPos ++;
					if (TempByt <= 0x83 || TempByt == 0x85)
						break;
				}
			}
			TempPos = CurPos - OfsList[CurEnv];
		}
		if (TempPos < 0x100)
			EnvData.Envelope[CurEnv].DataLen = (UINT8)TempPos;
		else
			EnvData.Envelope[CurEnv].DataLen = 0xFF;
		
		printf("%02X  ", 0x01 + CurEnv);
		if (ModePtr & ENVPTR_RAM)
			printf("  %04X", OfsList[CurEnv]);
		else
			printf("%06X", OfsList[CurEnv]);
		printf("  %04X\n", TempPos);
	}
	
	RemEnvs = EnvData.EnvCount;
	TempByt = 0x01;
	while(RemEnvs)
	{
		TempPos = 0xFFFFFFFF;
		for (CurEnv = 0x00; CurEnv < EnvData.EnvCount; CurEnv ++)
		{
			if (OfsList[CurEnv] < TempPos)
				TempPos = OfsList[CurEnv];
		}
		
		for (CurEnv = 0x00; CurEnv < EnvData.EnvCount; CurEnv ++)
		{
			if (OfsList[CurEnv] == TempPos)
			{
				sprintf(EnvData.Envelope[CurEnv].Name, "%s %u", ENV_NAMEBASE, TempByt);
				OfsList[CurEnv] = 0xFFFFFFFF;	// remove from offset list
				RemEnvs --;
			}
		}
		TempByt ++;
	}
	free(OfsList);	OfsList = NULL;
	
	if (EnvData.EnvCount && ! ReadOnlyMode)
	{
		if (ModePtr & ENVMODE_VOL)
			SaveEnvelopeFile("PSG.lst", &EnvData);
		else
			SaveEnvelopeFile("Modulat.lst", &EnvData);
	}
	printf("%02X Envelope%s extracted.\n", EnvData.EnvCount, (EnvData.EnvCount == 1) ? "" : "s");
	
	free(EnvData.Envelope);	EnvData.Envelope = NULL;
	
	return;
}

static void SaveEnvelopeFile(const char* FileName, const ENV_FILE* EnvData)
{
	FILE* hFile;
	UINT8 CurEnv;
	UINT32 StrLen;
	ENV_DATA* TempEnv;
	
	hFile = fopen(FileName, "wb");
	if (hFile == NULL)
	{
		printf("Error saving %s!\n", FileName);
		return;
	}
	
	fwrite(SIG_ENV, 0x01, 0x07, hFile);
	fputc(EnvData->EnvCount, hFile);
	
	for (CurEnv = 0x00; CurEnv < EnvData->EnvCount; CurEnv ++)
	{
		TempEnv = &EnvData->Envelope[CurEnv];
		StrLen = strlen(TempEnv->Name);
		if (StrLen >= 0x100)
			StrLen = 0xFF;
		fputc(StrLen, hFile);
		fwrite(TempEnv->Name, 0x01, StrLen, hFile);
		
		fputc(TempEnv->DataLen, hFile);
		fwrite(TempEnv->Data, 0x01, TempEnv->DataLen, hFile);
	}
	
	fclose(hFile);
	
	return;
}

static UINT32 GetNextAddr(UINT16 PtrCnt, const UINT32* PtrList, UINT32 MinAddr)
{
	UINT32 RetAddr;
	UINT32 CurPtr;
	
	RetAddr = 0xFFFFFFFF;
	for (CurPtr = 0x00; CurPtr < PtrCnt; CurPtr ++)
	{
		if (PtrList[CurPtr] > MinAddr && PtrList[CurPtr] < RetAddr)
			RetAddr = PtrList[CurPtr];
	}
	
	return RetAddr;
}
