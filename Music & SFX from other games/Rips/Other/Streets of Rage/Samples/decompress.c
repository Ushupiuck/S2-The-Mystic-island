#include <stdio.h>
#include <stdlib.h>

typedef unsigned char U;

FILE *outfile;

void writeDACByte(U byte)
{
	fwrite(&byte, 1, 1, outfile);
}

void decompress(U *data, int length)
{
	U buf[0x10];
	U outByte;
	U a, SaveDACByte;
	U *de, *hl;
	
	if (length == 0)
		return;
	de = buf;
	memcpy(buf, data, 0x10);
	de = data + 0x10;
	length = (length - 0x10) & 0x7FFF;
	outByte = 0x80; // upper nibble
	for (; length; length--) {
		a = *de & 0xF0;
		if (a == 0)
			for (a = buf[0]; a != 0; a--) {
				outByte += SaveDACByte;
				writeDACByte(outByte);
			}
		else {
			a = buf[a >> 4];
			SaveDACByte = a;
			a += outByte;
			outByte = a;
			writeDACByte(outByte);
		}
		a = *de & 0xF; // lower nibble
		if (a == 0)
			for (a = buf[0]; a != 0; a--) {
				outByte += SaveDACByte;
				writeDACByte(outByte);
			}
		else {
			a = buf[a];
			SaveDACByte = a;
			a += outByte;
			outByte = a;
			writeDACByte(outByte);
		}
		de++;
	}
}

int main(int argc, char *argv[])
{
	U *data;
	FILE *infile;
	int length;
	
	if (argc != 4) {
		fprintf(stderr, "usage: %s infile length-of-infile outfile\n", argv[0]);
		return 1;
	}
	infile = fopen(argv[1], "rb");
	if (infile == NULL) {
		fprintf(stderr, "%s: can't open\n", argv[1]);
		return 1;
	}
	length = atoi(argv[2]);
	data = (U *) malloc(length * sizeof (U));
	if (data == NULL) {
		fprintf(stderr, "memory exhausted - %s not touched\n", argv[3]);
		fclose(infile);
		return 1;
	}
	outfile = fopen(argv[3], "wb");
	if (outfile == NULL) {
		fprintf(stderr, "%s: can't create\n", argv[3]);
		fclose(infile);
		return 1;
	}
	fread(data, 1, length, infile);
	fclose(infile);
	decompress(data, length);
	fclose(outfile);
	return 0;
}
