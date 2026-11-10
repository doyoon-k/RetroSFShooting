using System;
using UnityEngine;

namespace RetroSF
{
    /// <summary>One pilot's flight: HP, shared weapon level, bombs and shield.</summary>
    public class SortieState
    {
        public enum WeaponType { Straight, Spread }

        public const int MaxBombs = 4;

        public event Action Changed;

        public int hp;
        public WeaponType activeWeapon = WeaponType.Straight;
        public int powerLevel = 1;
        public bool shield;
        int bombs;

        public int Bombs
        {
            get => bombs;
            set => bombs = Mathf.Clamp(value, 0, MaxBombs);
        }

        public SortieState(GameRules rules = null)
        {
            if (rules != null)
            {
                hp = rules.startingHp;
                Bombs = rules.startingBombs;
            }
        }

        public bool Damage(int amount = 1)
        {
            if (hp <= 0 || amount <= 0) return false;
            if (shield)
            {
                shield = false;
            }
            else
            {
                hp = Mathf.Max(0, hp - amount);
                powerLevel = Mathf.Max(1, powerLevel - 1);
            }
            Changed?.Invoke();
            return true;
        }

        public bool SpendBomb()
        {
            if (Bombs <= 0 || hp <= 0) return false;
            Bombs -= 1;
            Changed?.Invoke();
            return true;
        }

        public void SwitchWeapon()
        {
            activeWeapon = activeWeapon == WeaponType.Straight ? WeaponType.Spread : WeaponType.Straight;
            Changed?.Invoke();
        }

        public int CurrentPowerLevel() => powerLevel;

        public int RecoverablePowerups() => Mathf.Max(0, powerLevel - 1);

        public void Collect(Pickup.Kind kind, int maximumLevel)
        {
            switch (kind)
            {
                case Pickup.Kind.Power: powerLevel = Mathf.Min(powerLevel + 1, maximumLevel); break;
                case Pickup.Kind.Bomb: Bombs += 1; break;
                case Pickup.Kind.Shield: shield = true; break;
            }
            Changed?.Invoke();
        }
    }
}
