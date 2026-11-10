using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    [CreateAssetMenu(menuName = "RetroSF/Pilot Data")]
    public class PilotData : ScriptableObject
    {
        public string id = "";
        public string displayName = "";
        public string callsign = "";
        [TextArea(2, 8)] public string description = "";
        public bool isAi;
        public Color accent = new Color32(0x6d, 0xe5, 0xed, 0xff);
        public PlayerShip shipPrefab;
        [Header("Portraits")]
        public Sprite hangarPortrait;
        public Sprite normal;
        public Sprite oneDead;
        public Sprite twoDead;
        public Sprite fourDead;
        public Sprite damaged;
        public Sprite dead;
        [Header("Dialogue")]
        [TextArea(2, 6)] public string deathLine = "";
        [TextArea(2, 6)] public string victoryLine = "";

        public Sprite Portrait(int deadCount, bool isDamaged = false, bool isDead = false)
        {
            if (isDead) return dead != null ? dead : normal;
            Sprite normalTexture = normal;
            if (deadCount >= 4 && fourDead != null) normalTexture = fourDead;
            else if (deadCount >= 2 && twoDead != null) normalTexture = twoDead;
            else if (deadCount >= 1 && oneDead != null) normalTexture = oneDead;
            return isDamaged && damaged != null ? damaged : normalTexture;
        }
    }
}
