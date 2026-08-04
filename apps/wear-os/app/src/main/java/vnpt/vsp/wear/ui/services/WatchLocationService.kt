package vnpt.vsp.wear.ui.services

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Looper
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Battery-aware GPS location service for Wear OS.
 * AC3: battery-saving GPS modes.
 *
 * Supports two modes:
 * - Normal: HIGH_ACCURACY, updates every 5 seconds
 * - Battery-saving (ECO): LOW_POWER, updates every 30 seconds
 */
class WatchLocationService(private val context: Context) {

    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    private val _isBatterySaving = MutableStateFlow(false)
    val isBatterySaving: StateFlow<Boolean> = _isBatterySaving.asStateFlow()

    private val _latestLocation = MutableStateFlow<Location?>(null)
    val latestLocation: StateFlow<Location?> = _latestLocation.asStateFlow()

    private var locationCallback: LocationCallback? = null

    private fun buildLocationRequest(ecoMode: Boolean): LocationRequest {
        return LocationRequest.Builder(
            if (ecoMode) Priority.PRIORITY_LOW_POWER else Priority.PRIORITY_HIGH_ACCURACY,
            if (ecoMode) 30_000L else 5_000L
        )
            .setMinUpdateIntervalMillis(if (ecoMode) 15_000L else 2_000L)
            .setWaitForAccurateLocation(false)
            .build()
    }

    /**
     * Start receiving location updates.
     * @param ecoMode If true, use battery-saving LOW_POWER priority.
     */
    fun startLocationUpdates(ecoMode: Boolean = false) {
        if (!hasLocationPermission()) {
            android.util.Log.w("WatchLocationService", "Location permission not granted")
            return
        }

        _isBatterySaving.value = ecoMode

        stopLocationUpdates()

        val request = buildLocationRequest(ecoMode)

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { location ->
                    _latestLocation.value = location
                    android.util.Log.v(
                        "WatchLocationService",
                        "Location: lat=${location.latitude}, lon=${location.longitude}, " +
                                "acc=${location.accuracy}m, eco=$ecoMode"
                    )
                }
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(
                request,
                locationCallback!!,
                Looper.getMainLooper()
            )
            android.util.Log.d("WatchLocationService", "Location updates started, eco=$ecoMode")
        } catch (e: SecurityException) {
            android.util.Log.e("WatchLocationService", "Location permission denied", e)
        }
    }

    fun stopLocationUpdates() {
        locationCallback?.let {
            fusedLocationClient.removeLocationUpdates(it)
            locationCallback = null
            android.util.Log.d("WatchLocationService", "Location updates stopped")
        }
    }

    /**
     * Toggle between normal and battery-saving mode.
     */
    fun toggleBatterySaving() {
        val newMode = !_isBatterySaving.value
        startLocationUpdates(ecoMode = newMode)
    }

    /** Get last known location as a one-shot. Returns null if unavailable. */
    suspend fun getLastLocation(): Location? = suspendCancellableCoroutine { cont ->
        if (!hasLocationPermission()) {
            cont.resume(null)
            return@suspendCancellableCoroutine
        }

        try {
            fusedLocationClient.lastLocation
                .addOnSuccessListener { location ->
                    if (location != null && cont.isActive) {
                        _latestLocation.value = location
                        cont.resume(location)
                    } else if (cont.isActive) {
                        cont.resume(null)
                    }
                }
                .addOnFailureListener { e ->
                    if (cont.isActive) {
                        cont.resumeWithException(e)
                    }
                }
        } catch (e: SecurityException) {
            if (cont.isActive) cont.resume(null)
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }
}
