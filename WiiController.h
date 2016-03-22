#pragma once
#include "wiimote.h"


class WiiController  
{	
public:
	WiiController();
	~WiiController();

	void initialise();
	bool wiiInUse;
	wiimote mWiiMote; 
	wiimote_state wiiHistory;
};
