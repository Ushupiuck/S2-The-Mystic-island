// NOTE: You need to define STAT_DATA.

#ifndef __STATS_H__
#define __STATS_H__

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stddef.h>

//typedef int STAT_DATA;


typedef struct _stat_items
{
	unsigned int alloc;
	unsigned int count;
	STAT_DATA* data;
} STAT_ITEMS;
typedef struct _stat_block_list
{
	int start;
	int end;
	STAT_ITEMS items;
	
	struct _stat_block_list* prev;
	struct _stat_block_list* next;
} STAT_BLOCK;
typedef struct _area_stats
{
	STAT_BLOCK* BlkHead;
	STAT_BLOCK* BlkTail;
} AREA_STATS;


static void StatItems_Init(STAT_ITEMS* items);
static void StatItems_Deinit(STAT_ITEMS* items);
static void StatItems_Copy(STAT_ITEMS* dest, STAT_ITEMS* src);
static void StatItems_ReallocCheck(STAT_ITEMS* items);
static void StatItems_DataAppend(STAT_ITEMS* items, STAT_DATA data);

static void AreaStats_Init(AREA_STATS* stats);
static void AreaStats_Deinit(AREA_STATS* stats);
static STAT_BLOCK* AreaStats_CreateBlock(int start, int end, STAT_DATA value);
static void AreaStats_DestroyBlock(STAT_BLOCK* block);
static STAT_BLOCK* AreaStats_CopyBlock(STAT_BLOCK* element);
static void AreaStats_InsertBlock(AREA_STATS* stats, STAT_BLOCK* position, STAT_BLOCK* element);
static void AreaStats_DeleteBlock(AREA_STATS* stats, STAT_BLOCK* element);
static void AreaStats_SplitBlock(AREA_STATS* stats, STAT_BLOCK* block, int pos);
static STAT_BLOCK* AreaStats_GetNextBlockInRange(AREA_STATS* stats, STAT_BLOCK* startBlk, int rangeStart, int rangeEnd);
static STAT_BLOCK* AreaStats_GetLastBlockInRange(AREA_STATS* stats, STAT_BLOCK* startBlk, int rangeStart, int rangeEnd);
static void AreaStats_AddRangeI(AREA_STATS* stats, STAT_BLOCK* startBlk, STAT_BLOCK* endBlk, int start, int end, STAT_DATA value);
static char AreaStats_BlkDataMatch(STAT_BLOCK* blk1, STAT_BLOCK* blk2);
static void AreaStats_ConsolidateArea(AREA_STATS* stats, STAT_BLOCK* startBlk, STAT_BLOCK* endBlk, char checkBorders);
static void AreaStats_AddRange(AREA_STATS* stats, int start, int end, STAT_DATA value, char consolidate);


static void StatItems_Init(STAT_ITEMS* items)
{
	items->alloc = 0x10;
	items->count = 0;
	items->data = (STAT_DATA*)malloc(items->alloc * sizeof(STAT_DATA));
	
	return;
}

static void StatItems_Deinit(STAT_ITEMS* items)
{
	items->count = 0;
	items->alloc = 0;
	free(items->data);	items->data = NULL;
	
	return;
}

static void StatItems_Copy(STAT_ITEMS* dest, STAT_ITEMS* src)
{
	dest->alloc = src->alloc;
	dest->count = src->count;
	dest->data = (STAT_DATA*)malloc(dest->alloc * sizeof(STAT_DATA));
	memcpy(dest->data, src->data, dest->count * sizeof(STAT_DATA));
	
	return;
}

static void StatItems_ReallocCheck(STAT_ITEMS* items)
{
	if (items->count >= items->alloc)
	{
		items->alloc += 0x10;
		items->data = (STAT_DATA*)realloc(items->data, items->alloc * sizeof(STAT_DATA));
	}
	
	return;
}

static void StatItems_DataAppend(STAT_ITEMS* items, STAT_DATA data)
{
	StatItems_ReallocCheck(items);
	items->data[items->count] = data;
	items->count ++;
	
	return;
}

static void StatItems_DataInsertSort(STAT_ITEMS* items, STAT_DATA data)
{
	unsigned int curItm;
	
	StatItems_ReallocCheck(items);
	
	for (curItm = 0; curItm < items->count; curItm ++)
	{
		if (items->data[curItm] > data)
			break;
	}
	if (curItm < items->count)
		memmove(&items->data[curItm + 1], &items->data[curItm + 0], (items->count - curItm) * sizeof(STAT_DATA));
	items->data[curItm] = data;
	items->count ++;
	
	return;
}


static void AreaStats_Init(AREA_STATS* stats)
{
	stats->BlkHead = NULL;
	stats->BlkTail = NULL;
	
	return;
}

static void AreaStats_Deinit(AREA_STATS* stats)
{
	STAT_BLOCK* curBlk;
	STAT_BLOCK* lastBlk;
	
	curBlk = stats->BlkHead;
	while(curBlk != NULL)
	{
		lastBlk = curBlk;
		curBlk = curBlk->next;
		AreaStats_DestroyBlock(lastBlk);
	}
	stats->BlkHead = NULL;
	stats->BlkTail = NULL;
	
	return;
}

static STAT_BLOCK* AreaStats_CreateBlock(int start, int end, STAT_DATA value)
{
	STAT_BLOCK* newBlk;
	
	newBlk = (STAT_BLOCK*)malloc(sizeof(STAT_BLOCK));
	newBlk->prev = newBlk->next = NULL;
	newBlk->start = start;
	newBlk->end = end;
	StatItems_Init(&newBlk->items);
	StatItems_DataAppend(&newBlk->items, value);
	
	return newBlk;
}

static void AreaStats_DestroyBlock(STAT_BLOCK* block)
{
	StatItems_Deinit(&block->items);
	free(block);
	
	return;
}

static STAT_BLOCK* AreaStats_CopyBlock(STAT_BLOCK* element)
{
	STAT_BLOCK* newBlk;
	
	newBlk = (STAT_BLOCK*)malloc(sizeof(STAT_BLOCK));
	*newBlk = *element;
	StatItems_Copy(&newBlk->items, &element->items);
	
	return newBlk;
}

static void AreaStats_InsertBlock(AREA_STATS* stats, STAT_BLOCK* position, STAT_BLOCK* element)
{
	if (stats->BlkHead == NULL)	// insert as only element
	{
		element->prev = NULL;
		element->next = NULL;
		stats->BlkHead = element;
		stats->BlkTail = element;
	}
	else if (position == NULL)	// append to end
	{
		element->prev = stats->BlkTail;
		element->next = NULL;
		stats->BlkTail->next = element;
		stats->BlkTail = element;
	}
	else if (position == stats->BlkHead)	// prepend to start
	{
		element->prev = NULL;
		element->next = position;
		position->prev = element;
		stats->BlkHead = element;
	}
	else	// insert in the middle
	{
		element->prev = position->prev;
		element->next = position;
		position->prev->next = element;
		position->prev = element;
	}
	
	return;
}

static void AreaStats_DeleteBlock(AREA_STATS* stats, STAT_BLOCK* element)
{
	if (element->prev != NULL)
		element->prev->next = element->next;
	else //if (stats->BlkHead == element)
		stats->BlkHead = element->next;
	
	if (element->next != NULL)
		element->next->prev = element->prev;
	else //if (stats->BlkTail == element)
		stats->BlkTail = element->prev;
	
	StatItems_Deinit(&element->items);
	free(element);
	
	return;
}

// Split a block - e.g. [20..80] at 50 -> [20..50], [50..80]
static void AreaStats_SplitBlock(AREA_STATS* stats, STAT_BLOCK* block, int pos)
{
	STAT_BLOCK* newBlk;
	
	if (pos <= block->start || pos >= block->end)
		return;
	
	newBlk = AreaStats_CopyBlock(block);
	block->end = pos;
	newBlk->start = pos;
	AreaStats_InsertBlock(stats, block->next, newBlk);
	
	return;
}

// returns the position where a new block with the specified range would be inserted
static STAT_BLOCK* AreaStats_GetNextBlockInRange(AREA_STATS* stats, STAT_BLOCK* startBlk, int rangeStart, int rangeEnd)
{
	STAT_BLOCK* curBlk;
	
	if (stats->BlkTail == NULL || stats->BlkTail->end <= rangeStart)
		return NULL;
	for (curBlk = startBlk; curBlk != NULL; curBlk = curBlk->next)
	{
		if (curBlk->end > rangeStart)
			break;
	}
	return curBlk;
}

// returns the position of the first block AFTER the end of the specified range
static STAT_BLOCK* AreaStats_GetLastBlockInRange(AREA_STATS* stats, STAT_BLOCK* startBlk, int rangeStart, int rangeEnd)
{
	STAT_BLOCK* curBlk;
	
	if (stats->BlkTail == NULL || stats->BlkTail->end <= rangeStart)
		return NULL;
	for (curBlk = startBlk; curBlk != NULL; curBlk = curBlk->next)
	{
		if (curBlk->start > rangeEnd)
			break;
	}
	return curBlk;
}

// internal AddRange
static void AreaStats_AddRangeI(AREA_STATS* stats, STAT_BLOCK* startBlk, STAT_BLOCK* endBlk, int start, int end, STAT_DATA value)
{
	STAT_BLOCK* curBlk;
	STAT_BLOCK* lastBlk;
	STAT_BLOCK* nextBlk;
	
	if (stats->BlkHead == NULL || startBlk == NULL)
	{
		// range at very beginning/very end
		STAT_BLOCK* newBlk = AreaStats_CreateBlock(start, end, value);
		AreaStats_InsertBlock(stats, NULL, newBlk);
		return;
	}
	if (startBlk->start == start && startBlk->end == end)
	{
		// matches an existing block - just add the value
		StatItems_DataInsertSort(&startBlk->items, value);
		return;
	}
	if (end <= startBlk->start)
	{
		// insert before existing block
		STAT_BLOCK* newBlk = AreaStats_CreateBlock(start, end, value);
		AreaStats_InsertBlock(stats, startBlk, newBlk);
		return;
	}
	lastBlk = (endBlk != NULL) ? endBlk->prev : stats->BlkTail;
	if (start >= lastBlk->end)
	{
		// insert after existing block
		STAT_BLOCK* newBlk = AreaStats_CreateBlock(start, end, value);
		AreaStats_InsertBlock(stats, endBlk, newBlk);
		return;
	}
	else if (startBlk->end <= start && end <= lastBlk->start)
	{
		// insert between 2 existing blocks
		STAT_BLOCK* newBlk = AreaStats_CreateBlock(start, end, value);
		AreaStats_InsertBlock(stats, startBlk->next, newBlk);
		return;
	}
	
	// range is overlapping 1 or more blocks
	if (start < startBlk->start)
	{
		// range begins before startBlk - add [start .. startBlk.start]
		curBlk = startBlk;
		if (curBlk != stats->BlkHead)
			curBlk = curBlk->prev;
		AreaStats_AddRangeI(stats, curBlk, startBlk, start, startBlk->start, value);
		start = startBlk->start;
	}
	else if (start > startBlk->start)
	{
		// range begins in the middle of startBlk
		AreaStats_SplitBlock(stats, startBlk, start);
		startBlk = startBlk->next;
	}
	lastBlk = (endBlk != NULL) ? endBlk->prev : stats->BlkTail;	// refresh in case we split a block
	if (end > lastBlk->end)
	{
		// range ends after lastBlk - add [lastBlk->end .. end]
		AreaStats_AddRangeI(stats, lastBlk, endBlk, lastBlk->end, end, value);
		// then add to lastBlk
		AreaStats_AddRangeI(stats, lastBlk, lastBlk, lastBlk->start, lastBlk->end, value);
		end = lastBlk->start;
	}
	else if (end > lastBlk->start)
	{
		// range ends in the middle of lastBlk
		AreaStats_SplitBlock(stats, lastBlk, end);
		AreaStats_AddRangeI(stats, lastBlk, endBlk, lastBlk->start, lastBlk->end, value);
		end = lastBlk->start;
	}
	
	curBlk = startBlk;
	while(curBlk != lastBlk)
	{
		nextBlk = curBlk->next;
		
		AreaStats_AddRangeI(stats, curBlk, curBlk, curBlk->start, curBlk->end, value);	// add value to existing range
		if (curBlk->end < nextBlk->start)
			AreaStats_AddRangeI(stats, curBlk, nextBlk, curBlk->end, nextBlk->start, value);	// add new range
		curBlk = nextBlk;
	}
	
	return;
}

static void AreaStats_AddRange(AREA_STATS* stats, int start, int end, STAT_DATA value, char consolidate)
{
	STAT_BLOCK* stBlk;
	STAT_BLOCK* endBlk;
	
	if (start >= end)
		return;	// start must be < end
	
	stBlk = AreaStats_GetNextBlockInRange(stats, stats->BlkHead, start, end);
	endBlk = AreaStats_GetLastBlockInRange(stats, stBlk, start, end);
	AreaStats_AddRangeI(stats, stBlk, endBlk, start, end, value);
	
	if (consolidate)
	{
		if (stBlk == NULL)
			stBlk = stats->BlkTail;
		AreaStats_ConsolidateArea(stats, stBlk, endBlk, 1);
	}
	
	return;
}

static char AreaStats_BlkDataMatch(STAT_BLOCK* blk1, STAT_BLOCK* blk2)
{
	unsigned int curItm;
	
	if (blk1->items.count != blk2->items.count)
		return 0;
	for (curItm = 0; curItm < blk1->items.count; curItm ++)
	{
		if (blk1->items.data[curItm] != blk2->items.data[curItm])
			return 0;
	}
	
	return 1;
}

// consodidates blocks that contain the same elements within the range of the specified blocks
// Example: [30..50] {data 1, 3}, [50..75] {data 1, 3}, [75..90] {data 2, 3}
//          -> [30..75] {data 1, 3}, [75..90] {data 2, 3}
static void AreaStats_ConsolidateArea(AREA_STATS* stats, STAT_BLOCK* startBlk, STAT_BLOCK* endBlk, char checkBorders)
{
	STAT_BLOCK* curBlk;
	STAT_BLOCK* nextBlk;
	
	curBlk = startBlk;
	nextBlk = curBlk->next;
	// consodilate blocks within the specified area
	while(nextBlk != endBlk && nextBlk != NULL)
	{
		if (curBlk->end == nextBlk->start && AreaStats_BlkDataMatch(curBlk, nextBlk))
		{
			curBlk->end = nextBlk->end;
			AreaStats_DeleteBlock(stats, nextBlk);
		}
		else
		{
			curBlk = nextBlk;
		}
		nextBlk = curBlk->next;
	}
	if (! checkBorders)
		return;
	
	// consodilate blocks until  the first mismatch after endBlk
	while(nextBlk != NULL && curBlk->end == nextBlk->start && AreaStats_BlkDataMatch(curBlk, nextBlk))
	{
		curBlk->end = nextBlk->end;
		AreaStats_DeleteBlock(stats, nextBlk);
		nextBlk = curBlk->next;
	}
	
	// consodilate blocks until  the first mismatch before startBlk
	if (startBlk != stats->BlkHead)
	{
		nextBlk = startBlk;
		curBlk = nextBlk->prev;
		while(curBlk != NULL && curBlk->end == nextBlk->start && AreaStats_BlkDataMatch(curBlk, nextBlk))
		{
			curBlk->end = nextBlk->end;
			AreaStats_DeleteBlock(stats, nextBlk);
			nextBlk = curBlk;
			curBlk = curBlk->prev;
		}
	}
	
	return;
}

#endif	//__STATS_H__
