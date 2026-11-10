using System;
using UnityEngine;

namespace RetroSF
{
    public class WaveSequence : MonoBehaviour
    {
        public event Action<EnemyWave, int> EnemyRequested;
        public event Action BossRequested;

        public EnemyShip bossPrefab;

        [NonSerialized] public bool bossSent;

        public Transform BossMarker => transform.Find("BossMarker");

        public void Advance(float activationX)
        {
            if (bossSent) return;
            foreach (Transform child in transform)
            {
                var wave = child.GetComponent<EnemyWave>();
                if (wave != null && wave.isActiveAndEnabled) wave.Advance(activationX, RequestEnemy);
            }
            var marker = BossMarker;
            if (marker != null && marker.position.x <= activationX)
            {
                bossSent = true;
                BossRequested?.Invoke();
            }
        }

        void RequestEnemy(EnemyWave wave, int index) => EnemyRequested?.Invoke(wave, index);

        void OnDrawGizmos()
        {
            var marker = BossMarker;
            if (marker == null) return;
            Gizmos.color = new Color(1f, 0.3f, 0.3f, 0.9f);
            Gizmos.DrawWireSphere(marker.position, 80f);
        }
    }
}
