#include "WiiController.h"

WiiController::WiiController()
{
	wiiInUse = true;
	initialise();
}

WiiController::~WiiController()
{
}

void WiiController::initialise()
{		
	if (wiiInUse) 
	{
		int count = 0;
		while (!mWiiMote.Connect(wiimote::FIRST_AVAILABLE) && count < 3) 
		{
			count++;
			Sleep(1000);
		}

		if (!mWiiMote.IsConnected()) 
		{
			MessageBox(NULL, "Can't find any WiiMote. Continuing without WiiMote Support!", "Can't find WiiMote!", MB_OK);
			wiiInUse = false;
		}
		else 
		{
			mWiiMote.SetLEDs(0x01);
			mWiiMote.SetReportType(wiimote::IN_BUTTONS_ACCEL_IR_EXT);
		}
	}
}
 