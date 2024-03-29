#include <idc.idc>

/* makesig.idc: IDA script to automatically create and wildcard a function signature.
 * Copyright 2014, Asher Baker
 *
 * This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 */

/*
 * This is originally makesig.idc, but modified by 42 (FortyTwoFortyTwo) as makememsearch.idc to automatically create and wildcard a memory signature.
 */

static main()
{
	Wait(); // We won't work until autoanalysis is complete

	SetStatus(IDA_STATUS_WORK);

	auto pAddress = ScreenEA();
	
	auto sig = "", found = 0;
	auto pAddressEnd = pAddress + 0x1F;

	while (pAddress != BADADDR) {
		auto pInfo = DecodeInstruction(pAddress);
		if (!pInfo) {
			Warning("Something went terribly wrong D:");
			SetStatus(IDA_STATUS_READY);
			return;
		}

		auto i = 0, itemSize = ItemSize(pAddress), dtSize = GetDTSize(pInfo.Op0.dtype);
		
		if (pInfo.Op0.offb > 0 && pInfo.Op0.offb + dtSize <= itemSize)
		{
			//Store the instruction
			for (i = 0; i < pInfo.Op0.offb; i++) {
				sig = sig + sprintf("%02X ", Byte(pAddress + i));
			}
			
			//Store operand value as wildcard
			sig = sig + PrintWildcards(dtSize);
			
			//Store any remaining
			for (i = pInfo.Op0.offb + dtSize; i < itemSize; i++) {
				sig = sig + sprintf("%02X ", Byte(pAddress + i));
			}
		}
		else if (pInfo.n + dtSize == itemSize)
		{
			//Likely just n amount of instruction and dtsize amount of values
			for (i = 0; i < pInfo.n; i++) {
				sig = sig + sprintf("%02X ", Byte(pAddress + i));
			}
			
			sig = sig + PrintWildcards(dtSize);
		}
		else
		{
			//Unknown, just wildcard addresses
			for (i = 0; i < itemSize; i++) {
				auto pLoc = pAddress + i;
				if ((GetFixupTgtType(pLoc) & FIXUP_MASK) == FIXUP_OFF32) {
					sig = sig + PrintWildcards(4);
					i = i + 3;
				} else {
					sig = sig + sprintf("%02X ", Byte(pLoc));
				}
			}
		}
		
		if (IsGoodSig(sig)) {
			found = 1;
			break;
		}

		pAddress = NextHead(pAddress, pAddressEnd);
	}

	if (found == 0) {
		Warning("Ran out of bytes to create unique signature.");
		SetStatus(IDA_STATUS_READY);
		return;
	}

	auto len = strlen(sig) - 1, smsig = "\\x";
	for (i = 0; i < len; i++) {
		auto c = substr(sig, i, i + 1);
		if (c == " ") {
			smsig = smsig + "\\x";
		} else if (c == "?") {
			smsig = smsig + "2A";
		} else {
			smsig = smsig + c;
		}
	}

	Message("Memory Search:\n%s\n%s\n", sig, smsig);

	SetStatus(IDA_STATUS_READY);
	return;
}

static GetDTSize(dtype)
{
	if (dtype == dt_byte) {
		return 1;
	} else if (dtype == dt_word) {
		return 2;
	} else if (dtype == dt_dword) {
		return 4;
	} else if (dtype == dt_float) {
		return 4;
	} else if (dtype == dt_double) {
		return 8;
	} else if (dtype == dt_byte16) {
		return 16;
	} else {
		Warning("Unknown type size (%d)", dtype);
		return -1;
	}
}

static PrintWildcards(count)
{
	auto i = 0, string = "";
	for (i = 0; i < count; i++) {
		string = string + "? ";
	}

	return string;
}

static IsGoodSig(sig)
{

	auto count = 0, addr;
	addr = FindBinary(addr, SEARCH_DOWN|SEARCH_NEXT, sig);
	while (count <= 2 && addr != BADADDR) {
		count = count + 1;
		addr = FindBinary(addr, SEARCH_DOWN|SEARCH_NEXT, sig);
	}

	//Message("%s(%d)\n", sig, count);

	return (count == 1);
}