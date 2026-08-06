-- V34: bring the migration-built schema up to the entity model.
--
-- V1..V33 were written alongside the code but never executed anywhere: dev runs
-- Hibernate ddl-auto, the test suite runs H2 with Flyway disabled, and there is
-- no flyway_schema_history in any database. Nothing ever compared the two, so
-- they drifted until a Flyway-built database could not run the application at
-- all. Measured by running V0..V33 into an empty PostGIS database and diffing
-- against the schema Hibernate generates from the 64 @Entity classes:
--
--   10 tables in the entity model that no migration creates
--   175 columns on tables that do exist
--   69 columns whose migration type is not the entity type
--   17 columns and 1 table left over from a design the entities dropped
--
-- Every statement below is derived from that diff, not hand-written, so this
-- file says exactly what the gap was. FlywaySchemaMatchesEntityModelTest
-- re-runs the same comparison and fails if it ever reopens.
--
-- Three shape corrections were made at source instead of here, because they are
-- identity types that cannot be altered in place once foreign keys exist and
-- the migrations had never run: golf_facilities.id, courses.id and holes.id
-- were UUID in V16 and BIGINT in the entities, along with the facility_id /
-- course_id / hole_id columns referencing them in V16-V19. That mismatch is
-- what application-dev.yml describes when it says "the Flyway-based schema
-- cannot run the app as-is".
--
-- Safe on an empty database, which is the only place it will run: the NOT NULL
-- columns added below have no defaults and there are no rows to violate them.

-- ============================================================
-- 1. Tables the entity model has and the migrations never created
-- ============================================================
CREATE TABLE course_conditions_ops (confidence numeric(5,2), effective_date date not null, expiry_date date, version integer not null, course_id bigint not null, created_at timestamp(6) with time zone not null, effective_from timestamp(6) with time zone not null, expires_at timestamp(6) with time zone, id bigserial not null, last_verified_at timestamp(6) with time zone, updated_at timestamp(6) with time zone not null, severity varchar(20) check (severity in ('LOW','MODERATE','HIGH','CRITICAL')), condition_type varchar(50) not null check (condition_type in ('GREEN_SPEED','GREEN_FIRMNESS','FAIRWAY_FIRMNESS','ROUGH_DENSITY','BUNKER_CONDITION','COURSE_MOISTURE','COURSE_OVERALL','WEATHER_IMPACT','OTHER')), accuracy_class varchar(255) check (accuracy_class in ('A_RTK_SURVEYED','B_LICENSED_PROVIDER','C_VERIFIED_SATELLITE','D_UNVERIFIED_COMMUNITY')), description TEXT, license varchar(255), published_by varchar(255) not null, publisher varchar(255) not null, source varchar(255), verification_status varchar(255) check (verification_status in ('UNVERIFIED','PENDING_REVIEW','VERIFIED','REJECTED')), primary key (id));
CREATE TABLE data_license (expires_at timestamp(6) with time zone, issued_at timestamp(6) with time zone, license_id uuid not null, spdx_id varchar(50), licensee varchar(255), name varchar(255) not null, primary key (license_id));
CREATE TABLE data_license_redistribution_market (market_code varchar(2), license_id uuid not null);
CREATE TABLE draft_geometry_features (confidence numeric(5,2), effective_date date not null, expiry_date date, is_valid boolean not null, version integer not null, course_id bigint not null, created_at timestamp(6) with time zone not null, hole_id bigint, id bigserial not null, last_verified_at timestamp(6) with time zone, updated_at timestamp(6) with time zone, feature_uuid uuid not null unique, layer_type varchar(50) not null check (layer_type in ('TEE','FAIRWAY','ROUGH','GREEN','BUNKER','WATER_HAZARD','PENALTY_AREA','OUT_OF_BOUNDS','CART_PATH','LANDMARK')), accuracy_class varchar(255) check (accuracy_class in ('A_RTK_SURVEYED','B_LICENSED_PROVIDER','C_VERIFIED_SATELLITE','D_UNVERIFIED_COMMUNITY')), external_feature_id varchar(255), feature_name varchar(255), geometry text not null, license varchar(255), publisher varchar(255) not null, source varchar(255), validity_message text, verification_status varchar(255) check (verification_status in ('UNVERIFIED','PENDING_REVIEW','VERIFIED','REJECTED')), primary key (id), constraint uk_draft_geometry_course_layer_hole_feature unique (course_id, layer_type, hole_id, external_feature_id));
CREATE TABLE green_conditions (confidence numeric(5,2), effective_date date not null, expiry_date date, stimpmeter_reading numeric(4,1), version integer not null, created_at timestamp(6) with time zone not null, effective_from timestamp(6) with time zone not null, expires_at timestamp(6) with time zone, hole_id bigint not null, id bigserial not null, last_verified_at timestamp(6) with time zone, updated_at timestamp(6) with time zone not null, firmness varchar(10) check (firmness in ('SOFT','MEDIUM','FIRM','HARD')), moisture varchar(15) check (moisture in ('DRY','NORMAL','WET','SATURATED')), accuracy_class varchar(255) check (accuracy_class in ('A_RTK_SURVEYED','B_LICENSED_PROVIDER','C_VERIFIED_SATELLITE','D_UNVERIFIED_COMMUNITY')), license varchar(255), published_by varchar(255) not null, publisher varchar(255) not null, source varchar(255), verification_status varchar(255) check (verification_status in ('UNVERIFIED','PENDING_REVIEW','VERIFIED','REJECTED')), primary key (id));
CREATE TABLE market (active boolean not null, currency_code varchar(3), market_id varchar(2) not null, default_language varchar(10), measurement_unit varchar(20), date_format varchar(50), timezone varchar(50), name varchar(255) not null, primary key (market_id));
CREATE TABLE market_config (fork_gps_behavior boolean, fork_score_behavior boolean, market_id varchar(2) not null unique, redistribution_requires_license boolean, config_id uuid not null, primary key (config_id));
CREATE TABLE payment_booking_links (payment_confirmed boolean not null, confirmed_at timestamp(6) with time zone, created_at timestamp(6) with time zone not null, updated_at timestamp(6) with time zone not null, id uuid not null, payment_transaction_id uuid not null, confirmed_state varchar(30) check (confirmed_state in ('PENDING','SUCCEEDED','FAILED','REFUNDED','PARTIALLY_REFUNDED')), booking_id varchar(255) not null, primary key (id), constraint idx_payment_booking_link_booking_id_tx_id unique (booking_id, payment_transaction_id));
CREATE TABLE pin_positions_ops (confidence numeric(5,2), effective_date date not null, expiry_date date, version integer not null, created_at timestamp(6) with time zone not null, effective_from timestamp(6) with time zone not null, expires_at timestamp(6) with time zone, hole_id bigint not null, id bigserial not null, last_verified_at timestamp(6) with time zone, updated_at timestamp(6) with time zone not null, pin_position_type varchar(20), accuracy_class varchar(255) check (accuracy_class in ('A_RTK_SURVEYED','B_LICENSED_PROVIDER','C_VERIFIED_SATELLITE','D_UNVERIFIED_COMMUNITY')), license varchar(255), published_by varchar(255) not null, publisher varchar(255) not null, source varchar(255), verification_status varchar(255) check (verification_status in ('UNVERIFIED','PENDING_REVIEW','VERIFIED','REJECTED')), location geometry(Point,4326), primary key (id));
CREATE TABLE shots (confidence numeric(3,2), distance_meters numeric(10,2), distance_yards numeric(10,2), hole_number integer not null, is_mulligan boolean not null, is_penalty boolean not null, is_provisional boolean not null, shot_number integer not null, created_at timestamp(6) with time zone not null, deleted_at timestamp(6) with time zone, ended_at timestamp(6) with time zone, player_id bigint not null, started_at timestamp(6) with time zone not null, updated_at timestamp(6) with time zone not null, sync_status varchar(10) not null check (sync_status in ('pending','synced','failed')), source varchar(15) not null check (source in ('manual','detected','corrected')), club_id uuid, flight_id uuid not null, id uuid not null, merged_into_shot_id uuid, round_id uuid not null, lie varchar(20) check (lie in ('tee_box','fairway','rough','bunker','water','penalty','green','putt','out_of_bounds','cart_path','native_rough','primary_rough','secondary_rough','waste_bunker','desert','other')), result varchar(30) check (result in ('fairway_hit','green_hit','in_bunker','in_water','out_of_bounds','penalty','mulligan','provisional','scramble_save','chip_in','hole_out','in_the_hole','hit_L','hit_slice','hit_pull','hit_push','hit_hook','hit_thin','hit_heavy','whiff','unknown')), idempotency_key varchar(60) not null unique, conditions TEXT, end_location TEXT, start_location TEXT, primary key (id));

-- ============================================================
-- 2. Columns the entity model has and the migrations never created
-- ============================================================
ALTER TABLE bunkers ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE bunkers ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE bunkers ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE bunkers ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE bunkers ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE bunkers ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE bunkers ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE bunkers ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE bunkers ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE bunkers ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE cart_paths ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE cart_paths ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE cart_paths ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE cart_paths ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE cart_paths ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE cart_paths ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE cart_paths ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE cart_paths ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE cart_paths ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE cart_paths ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE course_conditions ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE course_conditions ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE course_conditions ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE course_conditions ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE course_conditions ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE course_conditions ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE course_conditions ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE course_conditions ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE courses ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE courses ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE courses ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE courses ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE courses ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE data_licenses ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE data_licenses ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE data_licenses ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE data_licenses ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE data_licenses ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE data_licenses ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE data_licenses ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE data_licenses ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS correction_id bigint;
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS rollback_note text;
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE data_versions ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE fairway_segments ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE fairway_segments ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE fairway_segments ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE fairway_segments ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE fairway_segments ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE fairway_segments ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE fairway_segments ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE fairway_segments ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE fairway_segments ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE fairway_segments ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE golf_facilities ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE golf_facilities ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE golf_facilities ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE golf_facilities ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE golf_facilities ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE golf_facilities ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE golf_facilities ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE golf_facilities ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE golf_facilities ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE golf_facilities ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE greens ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE greens ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE greens ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE greens ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE greens ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE greens ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE greens ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE greens ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE greens ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE greens ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE holes ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE holes ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE holes ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE holes ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE holes ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE holes ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE holes ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE holes ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE holes ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE holes ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE landmarks ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE landmarks ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE landmarks ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE landmarks ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE landmarks ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE landmarks ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE landmarks ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE landmarks ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE landmarks ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE landmarks ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE out_of_bounds ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE out_of_bounds ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE out_of_bounds ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE out_of_bounds ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE out_of_bounds ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE out_of_bounds ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE out_of_bounds ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE out_of_bounds ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE out_of_bounds ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE out_of_bounds ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE penalty_areas ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE penalty_areas ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE penalty_areas ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE penalty_areas ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE penalty_areas ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE penalty_areas ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE penalty_areas ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE penalty_areas ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE penalty_areas ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE penalty_areas ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE pin_positions ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE pin_positions ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE pin_positions ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE pin_positions ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE pin_positions ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE pin_positions ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE pin_positions ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE pin_positions ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE rounds ADD COLUMN IF NOT EXISTS course_id bigint;
ALTER TABLE rounds ADD COLUMN IF NOT EXISTS tournament_policy_id uuid;
ALTER TABLE rounds ADD COLUMN IF NOT EXISTS tournament_policy_version integer;
ALTER TABLE score_corrections ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL;
ALTER TABLE score_corrections ADD COLUMN IF NOT EXISTS hole_number integer;
ALTER TABLE score_corrections ADD COLUMN IF NOT EXISTS score_entry_id uuid;
ALTER TABLE tee_boxes ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE tee_boxes ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE tee_boxes ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE tee_boxes ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE tee_boxes ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE tee_boxes ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE tee_boxes ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE tee_boxes ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE tee_boxes ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE tee_boxes ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE tee_sets ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE tee_sets ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE tee_sets ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE tee_sets ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE tee_sets ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE tee_sets ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE tee_sets ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE tee_sets ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE tee_sets ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE tee_sets ADD COLUMN IF NOT EXISTS version integer NOT NULL;
ALTER TABLE tournament_results ADD COLUMN IF NOT EXISTS best_round_score integer;
ALTER TABLE tournament_results ADD COLUMN IF NOT EXISTS birdie_count integer;
ALTER TABLE tournament_results ADD COLUMN IF NOT EXISTS hole_scores varchar(200);
ALTER TABLE water_hazards ADD COLUMN IF NOT EXISTS accuracy_class varchar(255) CHECK (((accuracy_class)::text = ANY ((ARRAY['A_RTK_SURVEYED'::character varying, 'B_LICENSED_PROVIDER'::character varying, 'C_VERIFIED_SATELLITE'::character varying, 'D_UNVERIFIED_COMMUNITY'::character varying])::text[])));
ALTER TABLE water_hazards ADD COLUMN IF NOT EXISTS confidence numeric(5,2);
ALTER TABLE water_hazards ADD COLUMN IF NOT EXISTS effective_date date NOT NULL;
ALTER TABLE water_hazards ADD COLUMN IF NOT EXISTS expiry_date date;
ALTER TABLE water_hazards ADD COLUMN IF NOT EXISTS last_verified_at timestamptz;
ALTER TABLE water_hazards ADD COLUMN IF NOT EXISTS license varchar(255);
ALTER TABLE water_hazards ADD COLUMN IF NOT EXISTS publisher varchar(255) NOT NULL;
ALTER TABLE water_hazards ADD COLUMN IF NOT EXISTS source varchar(255);
ALTER TABLE water_hazards ADD COLUMN IF NOT EXISTS verification_status varchar(255) CHECK (((verification_status)::text = ANY ((ARRAY['UNVERIFIED'::character varying, 'PENDING_REVIEW'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying])::text[])));
ALTER TABLE water_hazards ADD COLUMN IF NOT EXISTS version integer NOT NULL;

-- ============================================================
-- 3. Columns whose migration type is not the entity type
-- ============================================================
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN carry_avg TYPE numeric(10,2) USING carry_avg::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN carry_max TYPE numeric(10,2) USING carry_max::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN carry_median TYPE numeric(10,2) USING carry_median::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN carry_min TYPE numeric(10,2) USING carry_min::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN carry_std_dev TYPE numeric(10,2) USING carry_std_dev::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN left_right_avg TYPE numeric(10,2) USING left_right_avg::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN left_right_std_dev TYPE numeric(10,2) USING left_right_std_dev::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN short_long_avg TYPE numeric(10,2) USING short_long_avg::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN short_long_std_dev TYPE numeric(10,2) USING short_long_std_dev::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN total_avg TYPE numeric(10,2) USING total_avg::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN total_max TYPE numeric(10,2) USING total_max::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN total_median TYPE numeric(10,2) USING total_median::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN total_min TYPE numeric(10,2) USING total_min::numeric(10,2);
-- double precision -> numeric(10,2)
ALTER TABLE club_performance ALTER COLUMN total_std_dev TYPE numeric(10,2) USING total_std_dev::numeric(10,2);
-- varchar(10) -> varchar(255)
ALTER TABLE course_alerts ALTER COLUMN accuracy_class TYPE varchar(255) USING accuracy_class::varchar(255);
-- timestamp -> timestamptz
ALTER TABLE course_alerts ALTER COLUMN acknowledged_at TYPE timestamptz USING acknowledged_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE course_alerts ALTER COLUMN created_at TYPE timestamptz USING created_at::timestamptz;
-- varchar(100) -> varchar(255)
ALTER TABLE course_alerts ALTER COLUMN license TYPE varchar(255) USING license::varchar(255);
-- varchar(20) -> varchar(255)
ALTER TABLE course_alerts ALTER COLUMN verification_status TYPE varchar(255) USING verification_status::varchar(255);
-- varchar(100) -> varchar(50)
ALTER TABLE course_conditions ALTER COLUMN condition_type TYPE varchar(50) USING condition_type::varchar(50);
-- varchar(50) -> varchar(20)
ALTER TABLE course_conditions ALTER COLUMN severity TYPE varchar(20) USING severity::varchar(20);
-- varchar(10) -> varchar(255)
ALTER TABLE course_corrections ALTER COLUMN accuracy_class TYPE varchar(255) USING accuracy_class::varchar(255);
-- timestamp -> timestamptz
ALTER TABLE course_corrections ALTER COLUMN created_at TYPE timestamptz USING created_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE course_corrections ALTER COLUMN last_verified_at TYPE timestamptz USING last_verified_at::timestamptz;
-- varchar(100) -> varchar(255)
ALTER TABLE course_corrections ALTER COLUMN license TYPE varchar(255) USING license::varchar(255);
-- varchar(1024) -> varchar(255)
ALTER TABLE course_corrections ALTER COLUMN reporter_evidence_url TYPE varchar(255) USING reporter_evidence_url::varchar(255);
-- timestamp -> timestamptz
ALTER TABLE course_corrections ALTER COLUMN reviewed_at TYPE timestamptz USING reviewed_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE course_corrections ALTER COLUMN submitted_at TYPE timestamptz USING submitted_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE course_corrections ALTER COLUMN updated_at TYPE timestamptz USING updated_at::timestamptz;
-- varchar(20) -> varchar(255)
ALTER TABLE course_corrections ALTER COLUMN verification_status TYPE varchar(255) USING verification_status::varchar(255);
-- varchar -> geometry
ALTER TABLE courses ALTER COLUMN location TYPE geometry USING ST_GeomFromText(location, 4326);
-- timestamp -> timestamptz
ALTER TABLE flights ALTER COLUMN confirmed_at TYPE timestamptz USING confirmed_at::timestamptz;
-- varchar(10) -> varchar(255)
ALTER TABLE flights ALTER COLUMN starting_tee TYPE varchar(255) USING starting_tee::varchar(255);
-- varchar -> geometry
ALTER TABLE golf_facilities ALTER COLUMN location TYPE geometry USING ST_GeomFromText(location, 4326);
-- timestamp -> timestamptz
ALTER TABLE golfer_accounts ALTER COLUMN anonymized_at TYPE timestamptz USING anonymized_at::timestamptz;
-- text -> varchar(1000)
ALTER TABLE golfer_accounts ALTER COLUMN anonymized_data TYPE varchar(1000) USING anonymized_data::varchar(1000);
-- varchar -> geometry
ALTER TABLE holes ALTER COLUMN green_location TYPE geometry USING ST_GeomFromText(green_location, 4326);
-- numeric(8,2) -> numeric(7,2)
ALTER TABLE holes ALTER COLUMN playing_length_meters TYPE numeric(7,2) USING playing_length_meters::numeric(7,2);
-- varchar -> geometry
ALTER TABLE holes ALTER COLUMN teeing_ground_location TYPE geometry USING ST_GeomFromText(teeing_ground_location, 4326);
-- varchar(50) -> varchar(20)
ALTER TABLE pin_positions ALTER COLUMN pin_position_type TYPE varchar(20) USING pin_position_type::varchar(20);
-- timestamp -> timestamptz
ALTER TABLE privacy_requests ALTER COLUMN created_at TYPE timestamptz USING created_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE privacy_requests ALTER COLUMN processed_at TYPE timestamptz USING processed_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE privacy_requests ALTER COLUMN requested_at TYPE timestamptz USING requested_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE privacy_requests ALTER COLUMN updated_at TYPE timestamptz USING updated_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE rounds ALTER COLUMN created_at TYPE timestamptz USING created_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE rounds ALTER COLUMN deleted_at TYPE timestamptz USING deleted_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE rounds ALTER COLUMN ended_at TYPE timestamptz USING ended_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE rounds ALTER COLUMN started_at TYPE timestamptz USING started_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE rounds ALTER COLUMN updated_at TYPE timestamptz USING updated_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE score_corrections ALTER COLUMN corrected_at TYPE timestamptz USING corrected_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE score_entries ALTER COLUMN created_at TYPE timestamptz USING created_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE score_entries ALTER COLUMN updated_at TYPE timestamptz USING updated_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE scores ALTER COLUMN created_at TYPE timestamptz USING created_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE scores ALTER COLUMN deleted_at TYPE timestamptz USING deleted_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE scores ALTER COLUMN updated_at TYPE timestamptz USING updated_at::timestamptz;
-- varchar(100) -> varchar(255)
ALTER TABLE tee_sets ALTER COLUMN name TYPE varchar(255) USING name::varchar(255);
-- timestamp -> timestamptz
ALTER TABLE tee_times ALTER COLUMN tee_time TYPE timestamptz USING tee_time::timestamptz;
-- varchar(30) -> varchar(255)
ALTER TABLE tie_break_rules ALTER COLUMN rule_type TYPE varchar(255) USING rule_type::varchar(255);
-- timestamp -> timestamptz
ALTER TABLE tournament_players ALTER COLUMN registration_time TYPE timestamptz USING registration_time::timestamptz;
-- varchar(20) -> varchar(255)
ALTER TABLE tournament_players ALTER COLUMN status TYPE varchar(255) USING status::varchar(255);
-- timestamp -> timestamptz
ALTER TABLE tournament_policies ALTER COLUMN created_at TYPE timestamptz USING created_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE tournament_policy_changes ALTER COLUMN changed_at TYPE timestamptz USING changed_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE tournament_results ALTER COLUMN published_at TYPE timestamptz USING published_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE tournaments ALTER COLUMN created_at TYPE timestamptz USING created_at::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE tournaments ALTER COLUMN end_date TYPE timestamptz USING end_date::timestamptz;
-- varchar(20) -> varchar(255)
ALTER TABLE tournaments ALTER COLUMN format TYPE varchar(255) USING format::varchar(255);
-- timestamp -> timestamptz
ALTER TABLE tournaments ALTER COLUMN registration_deadline TYPE timestamptz USING registration_deadline::timestamptz;
-- timestamp -> timestamptz
ALTER TABLE tournaments ALTER COLUMN start_date TYPE timestamptz USING start_date::timestamptz;
-- varchar(20) -> varchar(255)
ALTER TABLE tournaments ALTER COLUMN status TYPE varchar(255) USING status::varchar(255);

-- ============================================================
-- 4. Migration-only leftovers with no entity behind them
-- ============================================================
ALTER TABLE bunkers DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE cart_paths DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE course_conditions DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE courses DROP COLUMN IF EXISTS data_quality_metadata_id;
ALTER TABLE data_licenses DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE data_versions DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE fairway_segments DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE golf_facilities DROP COLUMN IF EXISTS data_quality_metadata_id;
ALTER TABLE greens DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE holes DROP COLUMN IF EXISTS data_quality_metadata_id;
ALTER TABLE landmarks DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE out_of_bounds DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE penalty_areas DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE pin_positions DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE tee_boxes DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE tee_sets DROP COLUMN IF EXISTS data_quality_id;
ALTER TABLE water_hazards DROP COLUMN IF EXISTS data_quality_id;
DROP TABLE IF EXISTS data_quality_metadata CASCADE;
