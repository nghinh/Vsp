package vnpt.vsp.wear.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

/**
 * Room database for Wear OS round and score persistence.
 * Local-first: all writes go here before sync.
 */
@Database(
    entities = [WearRoundEntity::class, WearHoleScoreEntity::class],
    version = 1,
    exportSchema = false
)
abstract class WearDatabase : RoomDatabase() {
    abstract fun roundDao(): WearRoundDao
    abstract fun scoreDao(): WearHoleScoreDao

    companion object {
        private const val DB_NAME = "wear_round.db"

        @Volatile
        private var INSTANCE: WearDatabase? = null

        fun getInstance(context: Context): WearDatabase {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: Room.databaseBuilder(
                    context.applicationContext,
                    WearDatabase::class.java,
                    DB_NAME
                )
                    .fallbackToDestructiveMigration()
                    .build()
                    .also { INSTANCE = it }
            }
        }
    }
}
