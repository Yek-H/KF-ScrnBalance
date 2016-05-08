/**
 * M14EBR version with 2 laser sight modes (green/red)
 * and slightly increased headshot multiplier to 1-headshot kill 6p HoE Husks and Sirens
 *
 * @see ScrnDamTypeM14EBR
 * @author PooSH, 2012
 */

class ScrnM14EBRBattleRifle extends M14EBRBattleRifle
dependson(ScrnLocalLaserDot)
    config(user);

var()	byte		                        LaserType; 	  //current laser type
var const class<ScrnLocalLaserDot>          LaserDotClass;
var     ScrnLocalLaserDot                   LaserDot;
var     name                                LaserAttachmentBone;


replication
{
	reliable if(Role < ROLE_Authority)
		ServerSetLaserType;
}


simulated function PostBeginPlay()
{
	super(KFWeapon).PostBeginPlay();
}

simulated function Destroyed()
{
	if (LaserDot != None)
		LaserDot.Destroy();

	if (LaserAttachment != None)
		LaserAttachment.Destroy();

	super(KFWeapon).Destroyed();
}


// Use alt fire to switch laser type
simulated function AltFire(float F)
{
    ToggleLaser();
}


//bring Laser to current state, which is indicating by LaserType 
simulated function ApplyLaserState()
{
	bLaserActive = LaserType > 0;
	if( Role < ROLE_Authority  )
		ServerSetLaserType(LaserType);

    if ( ThirdPersonActor != none )
        ScrnLaserWeaponAttachment(ThirdPersonActor).SetLaserType(LaserType);
    
    if ( !Instigator.IsLocallyControlled() )
        return;
    
	if( bLaserActive ) {
        if ( LaserDot == none )
            LaserDot = Spawn(LaserDotClass, self);
        LaserDot.SetLaserType(LaserType);
		//spawn 1-st person laser attachment for weapon owner
		if ( LaserAttachment == none ) {
			LaserAttachment = Spawn(LaserAttachmentClass,,,,);
			AttachToBone(LaserAttachment, LaserAttachmentBone);
		}
		ConstantColor'ScrnTex.Laser.LaserColor'.Color = 
			LaserDot.GetLaserColor(); // LaserAttachment's color
		LaserAttachment.bHidden = false;

	}
	else {
		if ( LaserAttachment != none )
			LaserAttachment.bHidden = true;
        if ( LaserDot != none )
            LaserDot.Destroy(); //bHidden = true;
	}
}
// Toggle laser modes: RED/GREEN/OFF
simulated function ToggleLaser()
{
	if( !Instigator.IsLocallyControlled() ) 
        return;

    if ( (++LaserType) > 2 )  
        LaserType = 0;
	ApplyLaserState();
}

simulated function BringUp(optional Weapon PrevWeapon)
{
	ApplyLaserState();
	Super.BringUp(PrevWeapon);
}

simulated function TurnOffLaser()
{
	if( !Instigator.IsLocallyControlled() )
		return;

    if( Role < ROLE_Authority  )
        ServerSetLaserType(0);

    bLaserActive = false;
    //don't change Laser type here, because we need to restore it state 
    //when next time weapon will be bringed up
    if ( LaserAttachment != none )
        LaserAttachment.bHidden = true;
    if (LaserDot != None)
        LaserDot.Destroy();
}



// Set the new fire mode on the server
function ServerSetLaserType(byte NewLaserType)
{
    LaserType = NewLaserType;
	bLaserActive = NewLaserType > 0; 
    ScrnLaserWeaponAttachment(ThirdPersonActor).SetLaserType(LaserType);   
}

simulated function bool PutDown()
{
	TurnOffLaser();
	return super(KFWeapon).PutDown();
}

simulated function WeaponTick(float dt)
{
    super(KFWeapon).WeaponTick(dt);
}

simulated function RenderOverlays( Canvas Canvas )
{
    local int i;
    local Vector StartTrace, EndTrace;
    local Vector HitLocation, HitNormal;
    local Actor Other;
    local vector X,Y,Z;
    local coords C;
	local KFFire KFM;
    local array<Actor> HitActors;

    if (Instigator == None)
        return;

    if ( Instigator.Controller != None )
        Hand = Instigator.Controller.Handedness;

    if ((Hand < -1.0) || (Hand > 1.0))
        return;

    // draw muzzleflashes/smoke for all fire modes so idle state won't
    // cause emitters to just disappear
    for ( i = 0; i < NUM_FIRE_MODES; ++i ) {
        if (FireMode[i] != None)
            FireMode[i].DrawMuzzleFlash(Canvas);
    }

    SetLocation( Instigator.Location + Instigator.CalcDrawOffset(self) );
    SetRotation( Instigator.GetViewRotation() + ZoomRotInterp);
	
	KFM = KFFire(FireMode[0]);

    // Handle drawing the laser dot
    if ( LaserDot != None )
    {
        //move LaserDot during fire animation too  -- PooSH
        if( bIsReloading )
		{
            C = GetBoneCoords(LaserAttachmentBone);
            X = C.XAxis;
            Y = C.YAxis;
            Z = C.ZAxis;
        }
        else 
            GetViewAxes(X, Y, Z);

        StartTrace = Instigator.Location + Instigator.EyePosition();
        EndTrace = StartTrace + 65535 * X;

        while (true) {
            Other = Trace(HitLocation, HitNormal, EndTrace, StartTrace, true);
            if ( ROBulletWhipAttachment(Other) != none ) {
                HitActors[HitActors.Length] = Other;
                Other.SetCollision(false);
                StartTrace = HitLocation + X;
            }
            else {
                if (Other != None && Other != Instigator && Other.Base != Instigator )
                    EndBeamEffect = HitLocation;
                else
                    EndBeamEffect = EndTrace;
                break;
            }
        }
        // restore collision
        for ( i=0; i<HitActors.Length; ++i )
            HitActors[i].SetCollision(true);

        LaserDot.SetLocation(EndBeamEffect - X*LaserDot.ProjectorPullback);

        if(  Pawn(Other) != none ) {
            LaserDot.SetRotation(Rotator(X));
            LaserDot.SetDrawScale(LaserDot.default.DrawScale * 0.5);
        }
        else if( HitNormal == vect(0,0,0) ) {
            LaserDot.SetRotation(Rotator(-X));
            LaserDot.SetDrawScale(LaserDot.default.DrawScale);
        }
        else {
            LaserDot.SetRotation(Rotator(-HitNormal));
            LaserDot.SetDrawScale(LaserDot.default.DrawScale);
        }
    }

    //PreDrawFPWeapon();    // Laurent -- Hook to override things before render (like rotation if using a staticmesh)

    bDrawingFirstPerson = true;
    Canvas.DrawActor(self, false, false, DisplayFOV);
    bDrawingFirstPerson = false;
}

	

defaultproperties
{
    LaserAttachmentBone="LightBone"
    LaserDotClass=Class'ScrnBalanceSrv.ScrnLocalLaserDot'
    LaserAttachmentClass=Class'ScrnBalanceSrv.ScrnLaserAttachmentFirstPerson'
    FireModeClass(0)=Class'ScrnBalanceSrv.ScrnM14EBRFire'
    Description="Updated M14 Enhanced Battle Rifle - Semi Auto variant. Equipped with a laser sight. A special lens allows to change laser's color on the fly."
    PickupClass=Class'ScrnBalanceSrv.ScrnM14EBRPickup'
    AttachmentClass=Class'ScrnBalanceSrv.ScrnM14EBRAttachment'
    ItemName="M14EBR SE"
}
