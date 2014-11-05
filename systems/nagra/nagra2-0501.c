/*
 * Softcam plugin to VDR (C++)
 *
 * This code is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This code is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 * Or, point your browser to http://www.gnu.org/copyleft/gpl.html
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nagra2.h"

// -- cMap0501 -----------------------------------------------------------------

class cMap0501 : public cMapCore {
protected:
  virtual bool Map(int f, unsigned char *data, int l);
  };

bool cMap0501::Map(int f, unsigned char *data, int l)
{
  l=GetOpSize(l);
  switch(f) {
    case 0x37:
      I.GetLE(data,l<<3);
      MonMul(B,I,B);
      break;
    default:
      return false;
    }
  return true;
}

// -- cN2Prov0501 --------------------------------------------------------------

class cN2Prov0501 : public cN2Prov, private cMap0501, public cN2Emu {
private:
  cMapMemHW *hwMapper;
  bool hasMaprom;
  //
  bool ProcessMap(int f);
  bool RomCallbacks(void);
  void AddRomCallbacks(void);
protected:
  virtual bool Algo(int algo, const unsigned char *hd, unsigned char *hw);
  virtual bool NeedsCwSwap(void) { return true; }
  virtual bool RomInit(void);
  virtual void TimerHandler(unsigned int num);
  virtual void AddMapCycles(unsigned int num) { AddCycles(num); }
  virtual unsigned int CpuCycles(void) { return Cycles(); }
public:
  cN2Prov0501(int Id, int Flags);
  virtual int ProcessBx(unsigned char *data, int len, int pos);
  virtual int RunEmu(unsigned char *data, int len, unsigned short load, unsigned short run, unsigned short stop, unsigned short fetch, int fetch_len);
  virtual void PostDecrypt(bool ecm) { PostDecryptSetup(ecm); }
  };

static cN2ProvLinkReg<cN2Prov0501,0x0501,(N2FLAG_MECM|N2FLAG_INV|N2FLAG_Bx)> staticPL0501;

cN2Prov0501::cN2Prov0501(int Id, int Flags)
:cN2Prov(Id,Flags)
{
  hwMapper=0; hasMaprom=false;
  SetMapIdent(Id);
}

bool cN2Prov0501::Algo(int algo, const unsigned char *hd, unsigned char *hw)
{
  if(algo==0x60) {
    hw[0]=hd[0];
    hw[1]=hd[1];
    hw[2]=hd[2]&0xF8;
    ExpandInput(hw);
    hw[63]|=0x80;
    hw[95]=hw[127]=hw[95]&0x7F;
    DoMap(SETSIZE,0,4);
    DoMap(IMPORT_J,hw+0x18);
    DoMap(IMPORT_D,hw+0x20);
    DoMap(IMPORT_B,hw+0x60);
    DoMap(0x37,hw+0x40);
    DoMap(EXPORT_C,hw);
    DoMap(IMPORT_A,hw+0x60);
    DoMap(0x3a);
    DoMap(EXPORT_C,hw+0x20);
    DoMap(0x43);
    DoMap(0x44,hw);
    memcpy(hw,hw+64,20);
    hw[0]&=7;
    DoMap(EXPORT_B,hw+3);
    memset(hw+3+0x20,0,128-(3+0x20));
    return true;
    }

  PRINTF(L_SYS_ECM,"%04X: unknown MECM algo %02x",id,algo);
  return false;
}

bool cN2Prov0501::RomInit(void)
{
  if(!AddMapper(hwMapper=new cMapMemHW(),HW_OFFSET,HW_REGS,0x00)) return false;
  if(   AddMapper(new cMapRom(0x3800,"Rom120_003800-003FFF.bin",0x00000),0x3800,0x0800,0x00)
     && AddMapper(new cMapRom(0x8000,"Rom120_408000-40CFFF.bin",0x00000),0x8000,0x5000,0x40)) {
    hasMaprom=true;
    PRINTF(L_SYS_EMU,"%04x: using native MAP rom",id);
    }
  return true;
}

bool cN2Prov0501::ProcessMap(int f)
{
  unsigned short addr;
  unsigned char tmp[256];
  int l=GetOpSize(Get(0x48));
  int dl=l<<3;

  switch(f) {
    case SETSIZE:
      DoMap(f,0,Get(0x48));
      break;
    case IMPORT_J:
    case IMPORT_A:
    case IMPORT_B:
    case IMPORT_C:
    case IMPORT_D:
    case IMPORT_LAST:
      addr=HILO(0x44);
      GetMem(addr,tmp,dl,0); DoMap(f,tmp,l);
      break;
    case EXPORT_J:
    case EXPORT_A:
    case EXPORT_B:
    case EXPORT_C:
    case EXPORT_D:
    case EXPORT_LAST:
      addr=HILO(0x44);
      DoMap(f,tmp,l); SetMem(addr,tmp,dl,0);
      break;
    case SWAP_A:
    case SWAP_B:
    case SWAP_C:
    case SWAP_D:
      addr=HILO(0x44);
      GetMem(addr,tmp,dl,0); DoMap(f,tmp,l); SetMem(addr,tmp,dl,0);
      break;
    case CLEAR_A:
    case CLEAR_B:
    case CLEAR_C:
    case CLEAR_D:
    case COPY_A_B:
    case COPY_B_A:
    case COPY_A_C:
    case COPY_C_A:
    case COPY_C_D:
    case COPY_D_C:
      DoMap(f);
      break;
    case 0x37:
      GetMem(HILO(0x44),tmp,dl,0);
      DoMap(f,tmp,l);
      break;
    case 0x3a:
      DoMap(f,0,l);
      break;
    case 0x43:
      DoMap(f);
      break;
    case 0x44:
      GetMem(0x400,tmp,64,0);
      DoMap(f,tmp);
      SetMem(0x440,tmp,20,0);
      break;
    default:
      PRINTF(L_SYS_EMU,"%04x: map call %02x not emulated",id,f);
      return false;
    }
  return true;
}

bool cN2Prov0501::RomCallbacks(void)
{
  unsigned int ea=GetPc();
  if(ea&0x8000) ea|=(cr<<16);
  switch(ea) {
    case 0x3840: //MAP Handler
      if(!ProcessMap(a)) return false;
      break;
    default:
      PRINTF(L_SYS_EMU,"%04X: unknown ROM breakpoint %04x",id,ea);
      return false;
    }
  if(ea>=0x8000) PopCr();
  PopPc();
  return true;
}

void cN2Prov0501::AddRomCallbacks(void)
{
  if(!hasMaprom)
    AddBreakpoint(0x3840); // map handler
}

int cN2Prov0501::ProcessBx(unsigned char *data, int len, int pos)
{
  if(data[pos-1]!=0xBC) {
    PRINTF(L_SYS_EMU,"%04X: bad nano %02X for ROM 120",id,data[pos-1]);
    return -1;
    }
  if(pos!=(0x93-0x80)) { // maybe exploitable
    PRINTF(L_SYS_EMU,"%04X: refuse to execute from %04x",id,0x80+pos);
    return -1;
    }
  if(Init(id,120)) {
    SetMem(0x80,data,len);
    SetPc(0x80+pos);
    SetSp(0x0FFF,0x0FE0);
    Set(0x0001,0xFF);
    Set(0x000E,0xFF);
    Set(0x0000,0x04);
    ClearBreakpoints();
    AddBreakpoint(0x821f);
    AddBreakpoint(0x0000);
    AddRomCallbacks();
    while(!Run(hasMaprom ? 20000:5000)) {
      if(GetPc()==0x821f) {
        GetMem(0x80,data,len);
        return a;
        }
      else if(GetPc()==0x0000) break;
      else if(!RomCallbacks()) break;
      }
    }
  return -1;
}

int cN2Prov0501::RunEmu(unsigned char *data, int len, unsigned short load, unsigned short run, unsigned short stop, unsigned short fetch, int fetch_len)
{
  if(Init(id,120)) {
    SetSp(0x0FFF,0x0EF8);
    SetMem(load,data,len);
    SetPc(run);
    ClearBreakpoints();
    AddBreakpoint(stop);
    if(stop!=0x0000) AddBreakpoint(0x0000);
    AddRomCallbacks();
    while(!Run(100000)) {
      if(GetPc()==0x0000 || GetPc()==stop) {
        GetMem(fetch,data,fetch_len);
        return 1;
        }
      else if(!RomCallbacks()) break;
      }
    }
  return -1;
}

void cN2Prov0501::TimerHandler(unsigned int num)
{
  if(hwMapper) hwMapper->AddCycles(num);
}

// -- cN2Prov0511 ----------------------------------------------------------------

static cN2ProvLinkReg<cN2Prov0501,0x0511,(N2FLAG_MECM|N2FLAG_INV)> staticPL0511;

// -- cN2Prov1101 ----------------------------------------------------------------

static cN2ProvLinkReg<cN2Prov0501,0x1101,(N2FLAG_MECM|N2FLAG_INV)> staticPL1101;

// -- cN2Prov3101 ----------------------------------------------------------------

static cN2ProvLinkReg<cN2Prov0501,0x3101,(N2FLAG_MECM|N2FLAG_INV)> staticPL3101;

