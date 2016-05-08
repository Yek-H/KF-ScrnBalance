class ScrnKnife extends Knife;

var transient bool bRestoreAltFire;
var transient float RestoreAltFireTime;
simulated state QuickMelee
{
    simulated function Timer()
    {
        if ( OldWeapon != none ) {
            Instigator.PendingWeapon = OldWeapon;
            PutDown();
        }
        else 
            GotoState('');
    }
    
    simulated function bool PutDown()
    {
        GotoState('');
        return global.PutDown();
    }
    
    simulated event WeaponTick(float dt)
    {
        super.WeaponTick(dt);
        
        if ( bRestoreAltFire && Level.TimeSeconds > RestoreAltFireTime ) {
            Instigator.Controller.bAltFire = 0; // restore to original state
            bRestoreAltFire = false;
        }
    }
    
    
    simulated function BringUp(optional Weapon PrevWeapon)
    {
        local int Mode; 
        
        HandleSleeveSwapping();
        KFHumanPawn(Instigator).SetAiming(false);
        bAimingRifle = false;
        bIsReloading = false;
        IdleAnim = default.IdleAnim;     

        
        for (Mode = 0; Mode < NUM_FIRE_MODES; Mode++) {
            FireMode[Mode].bIsFiring = false;
            FireMode[Mode].HoldTime = 0.0;
            FireMode[Mode].bServerDelayStartFire = false;
            FireMode[Mode].bServerDelayStopFire = false;
            FireMode[Mode].bInstantStop = false;
        }   
        
        OldWeapon = PrevWeapon;
        ClientState = WS_ReadyToFire;
        bRestoreAltFire = Instigator.Controller.bAltFire == 0;
        if ( bRestoreAltFire ) {
            Instigator.Controller.bAltFire = 1; // this is required to properly play attack animation
            RestoreAltFireTime = Level.TimeSeconds + 0.2;
        }
        ClientStartFire(1);
        SetTimer(FireMode[1].FireRate * 0.8, false);
    }
    
    simulated function EndState()
    {
        bRestoreAltFire = false;
        KFPawn(Instigator).SecondaryItem = none;
        OldWeapon = none;
    }
}


simulated function PostBeginPlay()
{
	super.PostBeginPlay();
	
    bCanThrow = KF_StoryGRI(Level.GRI) != none; // throw knife on dying only in story mode
}



defaultproperties
{
    PickupClass=Class'ScrnBalanceSrv.ScrnKnifePickup'
    ItemName="Knife SE"
    Description="Military Combat Knife"
    Priority=2
}