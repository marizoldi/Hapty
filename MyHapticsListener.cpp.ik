#include "MyHapticsListener.h"
#include <time.h>

MyHapticsListener::MyHapticsListener(MyApplication* app, const std::string &debugText)
  : mApp(app), isPressedButtonRotate(false), isPressedButtonMove(false), hasChanged(true)
{
	cameraPosition0 = entityPosition0 = hapticPosition0 = Ogre::Vector3::ZERO;
    Haptics::getSingleton().proxy.addHapticsListener(this);	// Registers self	
}

MyHapticsListener::~MyHapticsListener(void)
{ 
}

bool prepare_to_update(MyApplication * mApp)
{
	Ogre::Vector3 * vertices;
	unsigned long * indices;
	size_t vertex_count, index_count;	
	
	mApp->myHapticsListener->puppetTriangles.clear();
	mApp->haptics->device.clearShapes(); 
	mApp->haptics->device.transferObjects();

	for(int i = 0; i < mApp->puppets.size() ; ++i)
	{  
		vertex_count = index_count = 0;
		HAPI::Collision::Triangle mTriangle;
		Puppet* p = mApp->puppets[i];

		getMeshInformation( p->getEntity(), vertex_count, vertices, index_count, indices, p->getNode()->getPosition(),
							p->getNode()->getOrientation(),p->getNode()->getScale() );

		for (size_t j = 0; j < index_count; j+=3)
		{
			assert(indices[j] < vertex_count);   /// Making sure that this always happens...only in Debug

			mTriangle.a.x = vertices[indices[j  ]].x;
			mTriangle.a.y = vertices[indices[j  ]].y;
			mTriangle.a.z = vertices[indices[j  ]].z;
			mTriangle.b.x = vertices[indices[j+1]].x;
			mTriangle.b.y = vertices[indices[j+1]].y;
			mTriangle.b.z = vertices[indices[j+1]].z;
			mTriangle.c.x = vertices[indices[j+2]].x;
			mTriangle.c.y = vertices[indices[j+2]].y;
			mTriangle.c.z = vertices[indices[j+2]].z;

			mApp->myHapticsListener->puppetTriangles.push_back(mTriangle); 
		}
		delete[] indices;
		delete[] vertices;   ///clean-up
		mApp->myHapticsListener->hasChanged = false;
	}
	return true;
}

void MyHapticsListener::onPressed(const Haptics::Proxy::EventArgs& args)
{
	mApp->myHapticsListener->puppetTriangles.clear();
	mApp->haptics->device.clearShapes();
	mApp->haptics->device.transferObjects();

	hapticPosition0 = args.proxy.getPosition();

	thetaX0 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().y);
	thetaY0 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().x);
	thetaZ0 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().z);

	if ( args.isPressedButtonOnly(Haptics::Proxy::DBC_1) ) 
	{ 
		isPressedButtonMove = true;
		cameraPosition0 = mApp->mCamera->getParentNode()->getPosition();
		if(mApp->selectedEntity != NULL)
		{
			entityPosition0 = mApp->selectedEntity->getParentNode()->getPosition();
			if(!mApp->cameraReadyToBeMoved)
				{
					m_spring = new HAPI::HapticSpring(HAPI::Vec3(hapticPosition0.x,hapticPosition0.y,hapticPosition0.z), -15.0f);
					mApp->haptics->device.addEffect(m_spring);
					mApp->haptics->device.transferObjects();
				}
		}
	}

	if ( args.isPressedButtonOnly(Haptics::Proxy::DBC_0) )
	{	
		if ( mApp->selectedEntity == NULL) 
		return;
		else
			isPressedButtonRotate = true;

	}
}

void MyHapticsListener::onMoved( const Haptics::Proxy::EventArgs& args)
{
	//Haptics - movement & orientation
	Ogre::SceneNode* proxyNode = Haptics::getSingleton().proxy.getOgreEntity().getParentSceneNode();
	Ogre::Vector3 position = args.proxy.getPosition();
	Ogre::Quaternion orientation = args.proxy.getOrientation();
	orientation.normalise();
	proxyNode->setPosition(position);
	proxyNode->setOrientation(orientation); 
	 
	hapticDisplacement = position - hapticPosition0;

	///Rotation
	Ogre::Radian thetaX1 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().y);
	Ogre::Radian dThetaX = thetaX1 - thetaX0;
	Ogre::Radian thetaY1 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().x);
	Ogre::Radian dThetaY = thetaY1 - thetaY0;
	Ogre::Radian thetaZ1 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().z);
	Ogre::Radian dThetaZ = thetaZ1 - thetaZ0;

	Ogre::Vector3 mdirection =  proxyNode->getOrientation() * mApp->mCamera->getDirection();
	mdirection.normalise();

	Ogre::Vector3 xDirection = mdirection.crossProduct(Ogre::Vector3::UNIT_Y);
	xDirection.normalise();

	Ogre::Vector3 zDirection = mdirection.crossProduct(Ogre::Vector3::UNIT_X);
	zDirection.normalise();

	for(int i = 0; i < puppetTriangles.size() ; i++)
	{
		if (puppetTriangles[i].movingSphereIntersect(0.006, HAPI::Vec3(hapticPosition0.x,hapticPosition0.y,
			hapticPosition0.z), HAPI::Vec3(position.x,position.y,position.z)))
		 
		trianglesCloseToProxy.push_back(puppetTriangles[i]);
	}

	if (!isPressedButtonMove && !isPressedButtonRotate)
		mApp->select();
	
	else if( (!mApp->cameraReadyToBeMoved) && (!isPressedButtonRotate))
	{
		 if  (mApp->selectedEntity == NULL) 
		 return;
		 else 
			mApp->selectedEntity->getParentSceneNode()->setPosition(entityPosition0 + hapticDisplacement);

	}
	else if ( (isPressedButtonMove) && (!isPressedButtonRotate) && (!mApp->orbitOn))
	{
		mApp->mCamera->getParentSceneNode()->translate(hapticDisplacement*1.7, Ogre::Node::TS_PARENT);
		mApp->mCamera->getParentSceneNode()->rotate(-xDirection, dThetaX*0.4, Ogre::Node::TS_WORLD); 
		mApp->mCamera->getParentSceneNode()->rotate(Ogre::Vector3::UNIT_Y, dThetaY*0.4, Ogre::Node::TS_WORLD); 
		mApp->mCamera->getParentSceneNode()->rotate(mdirection, dThetaZ*0.4, Ogre::Node::TS_LOCAL); 

		thetaX0 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().y);
		thetaY0 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().x);
		thetaZ0 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().z); 
	}
	else if (mApp->orbitOn)
		mApp->orbitCamNode->yaw( Ogre::Degree(1), Ogre::Node::TS_LOCAL); 
	 
	else if (isPressedButtonRotate)
	{ 
		if(mApp->selectedEntity->hasSkeleton() && mApp->pinBone == NULL)
			mApp->pinBone = mApp->selectedEntity->getSkeleton()->getRootBone();
	
		else if(mApp->selectedEntity->getMesh()->getName() == "omni.mesh" || mApp->selectedEntity->getMesh()->getName() == "coneLight.mesh" || !(mApp->selectedEntity->hasSkeleton()) || mApp->pinBone == mApp->selectedEntity->getSkeleton()->getRootBone()) 
		{
			mApp->selectedEntity->getParentSceneNode()->rotate(-xDirection, dThetaX, Ogre::Node::TS_LOCAL); 
			mApp->selectedEntity->getParentSceneNode()->rotate(Ogre::Vector3::UNIT_Y, dThetaY, Ogre::Node::TS_LOCAL); 
			mApp->selectedEntity->getParentSceneNode()->rotate(mdirection, dThetaZ, Ogre::Node::TS_LOCAL);
			
			thetaX0 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().y);
			thetaY0 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().x);
			thetaZ0 = (Ogre::Radian)(Haptics::getSingleton().device.getGimbalAngles().z); 
		}
		else mApp->solveIK(mApp->pinBone, mApp->selectedBone, mApp->haptics->proxy.getPosition());
	
	}
}

void MyHapticsListener::onReleased( const Haptics::Proxy::EventArgs& args )
{
	mApp->deselect();

	if (args.isButtonReleased(Haptics::Proxy::DBC_1))		
		isPressedButtonMove = false;	

	if (args.isButtonReleased(Haptics::Proxy::DBC_0))
		isPressedButtonRotate = false;

	Haptics::getSingleton().device.removeEffect(m_spring); 
	Haptics::getSingleton().device.transferObjects();
	m_spring = 0;  
	hasChanged = true;
}

typedef std::vector<Puppet*> pupvector;

bool MyHapticsListener::frameStarted(const Ogre::FrameEvent& frame_event)
{	
	//mApp->readyToRender = true;
	if (hasChanged)
		prepare_to_update(mApp); // includes re-calculation of triangle position upon isChanged = true;
    //printf("Haptics RATE: %u\n",mApp->haptics->device.getHapticsRate());
	clock_t start,end;
	double timeelapsed;
	start = clock();  
       upload_triangles(mApp, mApp->haptics);
	 end = clock(); 
	timeelapsed = ((float)(end-start))/CLOCKS_PER_SEC;
	return Ogre::FrameListener::frameStarted(frame_event);
}

void upload_triangles(MyApplication* mApp, Haptics* haptics)
{ 	
	HAPI::Collision::AABBTree * the_tree = new HAPI::Collision::AABBTree(mApp->myHapticsListener->trianglesCloseToProxy);	
	HAPI::HAPISurfaceObject * my_surface = new HAPI::FrictionSurface(1.0, 0, 0, 0, true, true);
	HAPI::HapticTriangleTree * tree_shape = new HAPI::HapticTriangleTree(the_tree, my_surface, HAPI::Collision::FRONT);
	
	// Transfer shape to the haptics loop.
	haptics->device.addShape(tree_shape);
	haptics->device.transferObjects();
	mApp->myHapticsListener->trianglesCloseToProxy.clear();
	haptics->device.clearShapes();
}

void getMeshInformation(Ogre::Entity* entity, size_t &vertex_count,Ogre::Vector3* &vertices,
                        size_t &index_count, unsigned long* &indices, const Ogre::Vector3 &position, const Ogre::Quaternion &orient,
                        const Ogre::Vector3 &scale)
{
    bool added_shared = false;
    size_t current_offset = 0;
    size_t shared_offset = 0;
    size_t next_offset = 0;
    size_t index_offset = 0;
 
	Ogre::MeshPtr mesh = entity->getMesh();
	if (mesh.isNull()) { std::cerr << "Bad mesh pointer!\n" << std::endl; }

	bool useSoftwareBlendingVertices = entity->hasSkeleton();
	
	if (useSoftwareBlendingVertices)
		entity->_updateAnimation();

    // Calculate how many vertices and indices we're going to need
    for ( unsigned short i = 0; i < mesh->getNumSubMeshes(); i++)
    {
        Ogre::SubMesh * submesh = mesh->getSubMesh(i);
		if (submesh == NULL) { std::cerr << "Bad submesh pointer!!" << std::endl; continue; }

		// We only need to add the shared vertices once
		if(submesh->useSharedVertices)
		{		
			if( !added_shared )
			{
				vertex_count += mesh->sharedVertexData->vertexCount;
				added_shared = true;	
			}
			if (mesh->sharedVertexData->vertexCount == 0) { std::cerr << "No shared Vertex Data!!" << std::endl; continue; }
		}
		else
			vertex_count += submesh->vertexData->vertexCount;

		// Add the indices
		index_count += submesh->indexData->indexCount;	
	 }

	//std::cerr << "We have " << vertex_count << " vertices and " << index_count << " indices." << std::endl;

    // Allocate space for the vertices and indices
    vertices = new Ogre::Vector3[vertex_count];
    indices = new unsigned long[index_count];
 
    added_shared = false;
 
    // Run through the submeshes again, adding the data into the arrays
    for (unsigned short i = 0; i < mesh->getNumSubMeshes(); ++i)
    {
        Ogre::SubMesh * submesh = mesh->getSubMesh(i);
		//if (submesh == NULL) { std::cerr << "Bad submesh pointer!!!" << std::endl; continue; }

		Ogre::VertexData * vertex_data = NULL;
		 
		if (useSoftwareBlendingVertices)
			vertex_data = submesh->useSharedVertices ? entity->_getSkelAnimVertexData() : entity->getSubEntity(i)->_getSkelAnimVertexData();
		else
			vertex_data = submesh->useSharedVertices ? mesh->sharedVertexData : submesh->vertexData;

		if (vertex_data == NULL) { std::cerr << "Bad vertex data pointer!!!" << std::endl; continue; }

        if ((!submesh->useSharedVertices) || (submesh->useSharedVertices && !added_shared))
        {
            if(submesh->useSharedVertices)
            {
                added_shared = true;
                shared_offset = current_offset;
            }
 
            const Ogre::VertexElement* posElem = vertex_data->vertexDeclaration->findElementBySemantic(Ogre::VES_POSITION);
 
            Ogre::HardwareVertexBufferSharedPtr vbuf = vertex_data->vertexBufferBinding->getBuffer(posElem->getSource());
 
            unsigned char* vertex = static_cast<unsigned char*>(vbuf->lock(Ogre::HardwareBuffer::HBL_READ_ONLY));
 
            // There is _no_ baseVertexPointerToElement() which takes an Ogre::Real or a double
            //  as second argument. So make it float, to avoid trouble when Ogre::Real will
            //  be comiled/typedefed as double: //Ogre::Real* pReal;
            float* pReal;
            for( size_t j = 0; j < vertex_data->vertexCount; ++j, vertex += vbuf->getVertexSize())
            {
                posElem->baseVertexPointerToElement(vertex, &pReal);
                Ogre::Vector3 pt(pReal[0], pReal[1], pReal[2]);
                vertices[current_offset + j] = (orient * (pt * scale)) + position;
            }
            vbuf->unlock();
            next_offset += vertex_data->vertexCount;
        }
 
        Ogre::IndexData* index_data = submesh->indexData;
        size_t numTris = index_data->indexCount / 3;
        Ogre::HardwareIndexBufferSharedPtr ibuf = index_data->indexBuffer;
 
        bool use32bitindexes = (ibuf->getType() == Ogre::HardwareIndexBuffer::IT_32BIT);
 
        unsigned long* pLong = static_cast<unsigned long*>(ibuf->lock(Ogre::HardwareBuffer::HBL_READ_ONLY));
        unsigned short* pShort = reinterpret_cast<unsigned short*>(pLong);
 
        size_t offset = (submesh->useSharedVertices)? shared_offset : current_offset;
		size_t index_start = index_data->indexStart;
        size_t last_index = numTris*3 + index_start;
 
        if (use32bitindexes)
            for (size_t k = index_start; k < last_index; ++k)
            {
                indices[index_offset++] = pLong[k] + static_cast<unsigned long>( offset );
            }
 
        else
            for (size_t k = index_start; k < last_index; ++k)
            {
                indices[ index_offset++ ] = static_cast<unsigned long>( pShort[k] ) +
                    static_cast<unsigned long>( offset );
            }
 
        ibuf->unlock();
        current_offset = next_offset;
    }
}