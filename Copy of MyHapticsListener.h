#pragma once

#include "Haptics.h"
#include "MyApplication.h"

#include <HAPI/HapticSpring.h>

#include "HAPI/HAPIHapticShape.h"
#include "HAPI/HapticTriangleTree.h"
#include <HAPI/FrictionSurface.h>
#include <H3DUtil/Threads.h>
#include <H3DUtil/AutoRefVector.h>
#include <H3DUtil/RefCountedClass.h>

// Forward class declarations
class MyApplication;

class MyHapticsListener : public Haptics::Proxy::HapticsListener, public Ogre::FrameListener
{
private:
	MyApplication* mApp;
	MyApplication* data;
	bool isPressedButtonRotate;
	bool isPressedButtonMove;
	HAPI::HapticSpring* m_spring;

	Ogre::Radian thetaEntity,thetaBone;
	Ogre::Quaternion orientation0;
	Ogre::Vector3 hapticPosition0, entityPosition0, entityX, boneX, hapticDisplacement, lightPosition0, lightPositionX;

	std::vector<HAPI::Collision::AABBTree*> pointer_storage_AABBTree;
	std::vector<HAPI::HAPISurfaceObject*>   pointer_storage_Surface;
	std::vector<HAPI::HapticTriangleTree*>  pointer_storage_TriangleTree;

	void rotateEntityBone();
	void rotateLight();

    // From Haptics Listener:
	void onMoved(const Haptics::Proxy::EventArgs &args);
	void onPressed(const Haptics::Proxy::EventArgs& args);
	void onReleased(const Haptics::Proxy::EventArgs& args);

	// From Ogre FrameListener:
	bool frameStarted(const Ogre::FrameEvent& frame_event);
	inline bool frameRenderingQueued(const Ogre::FrameEvent& frame_event)
	  { return Ogre::FrameListener::frameRenderingQueued(frame_event); }
	inline bool frameEnded(const Ogre::FrameEvent& frame_event)
	  { return Ogre::FrameListener::frameEnded(frame_event); }

    void constructHapticTriangle(const Ogre::MeshPtr & pm);
 
public:
	MyHapticsListener(MyApplication* app, const std::string &debugText);
	~MyHapticsListener();

	bool hasChanged;
};

//H3DUtil::PeriodicThread::CallbackCode updateHAPI(void * data);
	
void getMeshInformation(Ogre::Entity *entity,
                        size_t &vertex_count,
                        Ogre::Vector3 * &vertices,        
                        size_t &index_count,
                        unsigned long * &indices,         
                        const Ogre::Vector3 &position,
                        const Ogre::Quaternion &orient,
                        const Ogre::Vector3 &scale);

void upload_puppet_to_device(const Ogre::MeshPtr & pm,
							 Ogre::Vector3 const vertices[],
							 unsigned long const indices[],
							 size_t vertex_count, size_t index_count,
							 Haptics * haptics);

