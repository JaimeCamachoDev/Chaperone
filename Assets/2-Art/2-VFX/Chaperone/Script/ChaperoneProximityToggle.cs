using UnityEngine;

[DisallowMultipleComponent]
public class ChaperoneProximityFade : MonoBehaviour
{
    [Header("Targets")]
    [SerializeField] private Renderer[] targets;    // Renderers que usan el shader de rejilla
    [SerializeField] private Collider[] colliders;  // Colliders de las paredes / volumen de interés

    [Header("Distancia de activación")]
    [Tooltip("A esta distancia o menos, la rejilla debería estar totalmente visible (factor=1).")]
    [SerializeField] private float showDistance = 2f;

    [Tooltip("Ancho de la banda de transición (metros). Aumenta para un borde más suave.")]
    [SerializeField] private float fadeBand = 0.75f;

    [Header("Suavizado temporal")]
    [Tooltip("Tiempo aproximado (seg) para alcanzar el nuevo valor. 0 = sin suavizado temporal.")]
    [SerializeField] private float smoothTime = 0.15f;

    [Tooltip("Velocidad máxima de cambio para el SmoothDamp (0 = ilimitada).")]
    [SerializeField] private float maxSpeed = 0f;

    [Header("Propiedad del shader")]
    [SerializeField] private string factorProperty = "_Alpha";

    private Camera cam;
    private MaterialPropertyBlock mpb;

    // Estado temporal
    private float currentFactor = 0f;
    private float factorVelocity = 0f;

    void Awake()
    {
        cam = Camera.main;
        mpb = new MaterialPropertyBlock();

        if (targets == null || targets.Length == 0)
            targets = GetComponentsInChildren<Renderer>(true);
    }

    void LateUpdate()
    {
        if (!cam) return;

        Vector3 cpos = cam.transform.position;
        float minDist = float.PositiveInfinity;

        // 1) Distancia real a superficie si hay colliders
        if (colliders != null && colliders.Length > 0)
        {
            for (int i = 0; i < colliders.Length; i++)
            {
                var col = colliders[i];
                if (!col) continue;
                Vector3 closest = col.ClosestPoint(cpos);
                float d = Vector3.Distance(cpos, closest);
                if (d < minDist) minDist = d;
            }
        }

        // 2) Si no hay colliders, aproximamos con AABB de los renderers
        if (!float.IsFinite(minDist) || minDist == float.PositiveInfinity)
        {
            if (targets != null)
            {
                for (int i = 0; i < targets.Length; i++)
                {
                    var r = targets[i];
                    if (!r) continue;
                    Vector3 closest = r.bounds.ClosestPoint(cpos);
                    float d = Vector3.Distance(cpos, closest);
                    if (d < minDist) minDist = d;
                }
            }
        }

        // ----- Fade espacial (smoothstep) -----
        // Rango de transición: [showDistance, showDistance + fadeBand]
        // <= showDistance  -> factor 1 (totalmente visible)
        // >= showDistance+fadeBand -> factor 0 (oculto)
        float a = showDistance;
        float b = showDistance + Mathf.Max(0.0001f, fadeBand);
        float t = Mathf.InverseLerp(a, b, minDist);      // 0 cerca, 1 lejos
        float targetFactor = 1f - SmoothStep01(t);       // 1 cerca, 0 lejos

        // ----- Fade temporal -----
        float newFactor;
        if (smoothTime > 0f)
            newFactor = Mathf.SmoothDamp(currentFactor, targetFactor, ref factorVelocity, smoothTime, (maxSpeed <= 0f ? Mathf.Infinity : maxSpeed));
        else
            newFactor = targetFactor;

        currentFactor = Mathf.Clamp01(newFactor);

        // Aplicar al/los renderer(s) con MPB
        if (targets != null)
        {
            for (int i = 0; i < targets.Length; i++)
            {
                var r = targets[i];
                if (!r) continue;
                r.GetPropertyBlock(mpb);
                mpb.SetFloat(factorProperty, currentFactor);
                r.SetPropertyBlock(mpb);
            }
        }
    }

    // Suavizado cúbico estándar (igual que smoothstep 0..1)
    private static float SmoothStep01(float x)
    {
        x = Mathf.Clamp01(x);
        return x * x * (3f - 2f * x);
    }
}
