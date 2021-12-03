
-- DROP SCHEMA IF EXISTS api CASCADE;
CREATE SCHEMA api;
CREATE SCHEMA ingest;

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: get_addresses_in_bbox(numeric, numeric, numeric, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--
CREATE FUNCTION api.get_addresses_in_bbox(
  minx numeric,
  miny numeric,
  maxx numeric,
  maxy numeric
) RETURNS json
  LANGUAGE sql IMMUTABLE
AS $f$
SELECT CASE
    j.features_count
    WHEN 1 THEN j.features
    ELSE json_build_object(
      'type',
      'FeatureCollection',
      'features',
      j.features
    )
  END AS response
FROM (
    SELECT count(r) AS features_count,
      json_agg(ST_AsGeoJSON(r, 'geom', 6)::json) AS features
    FROM (
        SELECT n.geom,
          n.properties->>'_id' AS _id,
          n.properties->>'address' AS address,
          n.properties->>'display_name' AS display_name,
          n.properties->>'barrio' AS barrio,
          n.properties->>'comuna' AS comuna,
          n.properties->>'municipality' AS municipality,
          n.properties->>'divipola' AS divipola,
          n.properties->>'country' AS country
        FROM (
            SELECT *
            FROM api.search s
            WHERE ST_Contains(
                ST_SetSRID(
                    api.viewbox_to_polygon(minx, miny, maxx, maxy),
                    4326
                ),
              s.geom
              )
          ) n
      ) r
  ) j;
$f$;


--
-- Name: lookup(text); Type: FUNCTION; Schema: api; Owner: postgres
--
CREATE FUNCTION api.lookup(address text) RETURNS json
 LANGUAGE sql IMMUTABLE
AS $f$
SELECT json_build_object(
		'type',
		'Feature',
		'geometry',
		ST_AsGeoJSON(geom, 6, 0)::json,
		'properties',
		properties
	) AS result
FROM (
	SELECT *
	FROM api.search s
	WHERE s.properties->>'address' = address  OR s.properties->>'_id' = address
)r
$f$;

--
-- Name: pgrst_watch(); Type: FUNCTION; Schema: api; Owner: postgres
--
CREATE FUNCTION api.pgrst_watch() RETURNS event_trigger
    LANGUAGE plpgsql
AS $f$ BEGIN
    NOTIFY pgrst, 'reload schema';
END;
$f$;


--
-- Name: reverse(numeric, numeric, numeric, integer); Type: FUNCTION; Schema: api; Owner: postgres
--
CREATE FUNCTION api.reverse(lon numeric, lat numeric, radius numeric DEFAULT 3, lim integer DEFAULT 1) RETURNS json
    LANGUAGE sql IMMUTABLE
    AS $$
WITH nearby AS (
  SELECT *,
    b.geom::geography <->ST_POINT(lon, lat) as dist
  FROM (
      SELECT *
      FROM api.search s
      WHERE ST_DWithin(
          s.geom::geography,
          ST_POINT(lon, lat),
          radius
        )
    ) b
  ORDER BY dist
  LIMIT lim
)
SELECT CASE
    j.features_count
    WHEN 1 THEN j.features
    ELSE json_build_object(
      'type',
      'FeatureCollection',
      'features',
      j.features
    )
  END AS response
FROM (
    SELECT count(r) AS features_count,
      json_agg(ST_AsGeoJSON(r, 'geom', 6)::json) AS features
    FROM (
        SELECT s.geom,
		  round(s.dist, 2) AS distance,
          s.properties->>'_id' AS _id,
          s.properties->>'address' AS address,
          s.properties->>'display_name' AS display_name,
          s.properties->>'barrio' AS barrio,
          s.properties->>'comuna' AS comuna,
          s.properties->>'municipality' AS municipality,
          s.properties->>'divipola' AS divipola,
          s.properties->>'country' AS country
        FROM (
            SELECT *
            FROM nearby
          ) s
      ) r
  ) j;
$$;


--
-- Name: search(text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--
CREATE FUNCTION api.search(_q text, lim integer DEFAULT 100) RETURNS json
    LANGUAGE sql IMMUTABLE
    AS $$
WITH q AS (
  SELECT *,
    lower(_q) <->q AS diff
  FROM api.search
  ORDER BY diff
  LIMIT lim
)
SELECT CASE
    j.features_count
    WHEN 1 THEN j.features
    ELSE json_build_object(
      'type',
      'FeatureCollection',
	  'query',
      _q,
      'features',
      j.features
    )
  END AS response
FROM (
    SELECT count(r) AS features_count,
      json_agg(ST_AsGeoJSON(r, 'geom', 6)::json) AS features
    FROM (
        SELECT s.geom,
          1 - s.diff AS similarity,
          s.properties->>'_id' AS _id,
          s.properties->>'address' AS address,
          s.properties->>'display_name' AS display_name,
          s.properties->>'barrio' AS barrio,
          s.properties->>'comuna' AS comuna,
          s.properties->>'municipality' AS municipality,
          s.properties->>'divipola' AS divipola,
          s.properties->>'country' AS country
        FROM (
            SELECT *
            FROM q
            WHERE q.diff <.95
          ) s
      ) r
  ) j;
$$;

--
-- Name: search_bounded(text, numeric[], integer); Type: FUNCTION; Schema: api; Owner: postgres
--
CREATE FUNCTION api.search_bounded(_q text, viewbox numeric[], lim integer DEFAULT 100) RETURNS json
    LANGUAGE sql IMMUTABLE
    AS $$
WITH q AS (
  SELECT *,
    lower(_q) <-> q.spq AS diff
  FROM (
      SELECT *
      FROM api.search
      WHERE ST_Contains(
          ST_SetSRID(
            api.viewbox_to_polygon(viewbox[1], viewbox[2], viewbox[3], viewbox[4]),
            4326
          ),
          geom
        )
    ) q
  ORDER BY diff
  LIMIT lim
)
SELECT CASE
    j.features_count
    WHEN 1 THEN j.features
    ELSE json_build_object(
      'type',
      'FeatureCollection',
	  'query',
      _q,
      'features',
      j.features
    )
  END AS response
FROM (
    SELECT count(r) AS features_count,
      json_agg(ST_AsGeoJSON(r, 'geom', 6)::json) AS features
    FROM (
        SELECT s.geom,
		  1-s.diff AS similarity,
          s.properties->>'_id' AS _id,
          s.properties->>'address' AS address,
          s.properties->>'display_name' AS display_name,
          s.properties->>'barrio' AS barrio,
          s.properties->>'comuna' AS comuna,
          s.properties->>'municipality' AS municipality,
          s.properties->>'divipola' AS divipola,
          s.properties->>'country' AS country
        FROM (
            SELECT *
            FROM q
            WHERE q.diff < .95
          ) s
      ) r
  ) j
$$;


--
-- Name: search_nearby(text, numeric[], numeric, integer); Type: FUNCTION; Schema: api; Owner: postgres
--
CREATE FUNCTION api.search_nearby(_q text, loc numeric[], radius numeric DEFAULT 200, lim integer DEFAULT 100) RETURNS json
    LANGUAGE sql IMMUTABLE
    AS $$
WITH q AS (
  SELECT *,
    lower(_q) <-> q.spq AS diff
  FROM (
            SELECT *
            FROM (
                SELECT *,
                  s.geom::geography <->ST_POINT(loc[1], loc[2]) as dist
                FROM api.search s
              ) b
            WHERE b.dist <= radius
          ) q
  ORDER BY diff, dist
  LIMIT lim
)
SELECT CASE
    j.features_count
    WHEN 1 THEN j.features
    ELSE json_build_object(
      'type',
      'FeatureCollection',
	  'query',
      _q,
      'features',
      j.features
    )
  END AS response
FROM (
    SELECT count(r) AS features_count,
      json_agg(ST_AsGeoJSON(r, 'geom', 6)::json) AS features
    FROM (
        SELECT s.geom,
		  1-s.diff AS similarity,
		  round(s.dist, 2) AS distance,
          s.properties->>'_id' AS _id,
          s.properties->>'address' AS address,
          s.properties->>'display_name' AS display_name,
          s.properties->>'barrio' AS barrio,
          s.properties->>'comuna' AS comuna,
          s.properties->>'municipality' AS municipality,
          s.properties->>'divipola' AS divipola,
          s.properties->>'country' AS country
        FROM (
            SELECT *
            FROM q
            WHERE q.diff < .95
          ) s
      ) r
  ) j
$$;


--
-- Name: to_geojson(anyelement); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.to_geojson(toformat anyelement) RETURNS json
    LANGUAGE sql IMMUTABLE
    AS $$SELECT CASE
    j.features_count
    WHEN 1 THEN j.features
    ELSE json_build_object(
      'type',
      'FeatureCollection',
      'features',
      j.features
    )
  END AS response
FROM (
    SELECT count(r) AS features_count,
      json_agg(ST_AsGeoJSON(r, 'geom', 6)::json) AS features
    FROM (
        SELECT s.geom,
          round(s.dist, 2) AS distance,
          s.properties->>'_id' AS _id,
          s.properties->>'address' AS address,
          s.properties->>'display_name' AS display_name,
          s.properties->>'barrio' AS barrio,
          s.properties->>'comuna' AS comuna,
          s.properties->>'municipality' AS municipality,
          s.properties->>'divipola' AS divipola,
          s.properties->>'country' AS country
        FROM (
          SELECT *
          FROM pg_typeof(toformat)
          ) s
      ) r
  ) j$$;


--
-- Name: viewbox_to_polygon(numeric, numeric, numeric, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--
CREATE FUNCTION api.viewbox_to_polygon(minx numeric, miny numeric, maxx numeric, maxy numeric) RETURNS text
    LANGUAGE sql
    AS $$SELECT ST_AsText(
		ST_Envelope(
			ST_Collect(
				ST_Point(minx, miny),
				ST_Point(maxx, maxy)
			)
		)
	)$$;

--
-- Name: any_load(text, text, text, text, real, text, text[], text, boolean); Type: FUNCTION; Schema: ingest; Owner: postgres
--
CREATE FUNCTION ingest.any_load(p_method text, p_fileref text, p_ftname text, p_tabname text, p_pck_id real, p_pck_fileref_sha256 text, p_tabcols text[] DEFAULT NULL::text[], p_geom_name text DEFAULT 'geom'::text, p_to4326 boolean DEFAULT true) RETURNS text
    LANGUAGE plpgsql
AS $f$
  DECLARE
    q_file_id integer;
    q_query text;
    q_query_cad text;
    feature_id_col text;
    use_tabcols boolean;
    msg_ret text;
    num_items bigint;
  BEGIN
  IF p_method='csv2sql' THEN
    p_fileref := p_fileref || '.csv';
    -- other checks
  ELSE
    p_fileref := regexp_replace(p_fileref,'\.shp$', '') || '.shp';
  END IF;
  q_file_id := ingest.getmeta_to_file(p_fileref,p_ftname,p_pck_id,p_pck_fileref_sha256); -- not null when proc_step=1. Ideal retornar array.
  IF q_file_id IS NULL THEN
    RETURN format('ERROR: file-read problem or data ingested before, see %s.',p_fileref);
  END IF;
  IF p_tabcols=array[]::text[] THEN  -- condição para solicitar todas as colunas
    p_tabcols = rel_columns(p_tabname);
  END IF;
  IF 'gid'=ANY(p_tabcols) THEN
    feature_id_col := 'gid';
    p_tabcols := array_remove(p_tabcols,'gid');
  ELSE
    feature_id_col := 'row_number() OVER () AS gid';
  END IF;
  -- RAISE NOTICE E'\n===tabcols:\n %\n===END tabcols\n',  array_to_string(p_tabcols,',');
  IF p_tabcols is not NULL AND array_length(p_tabcols,1)>0 THEN
    p_tabcols   := sql_parse_selectcols(p_tabcols); -- clean p_tabcols
    use_tabcols := true;
  ELSE
    use_tabcols := false;
  END IF;
  IF 'geom'=ANY(p_tabcols) THEN
    p_tabcols := array_remove(p_tabcols,'geom');
  END IF;
  q_query := format(
      $$
      WITH
      scan AS (
        SELECT %s, gid, properties,
               CASE
                 WHEN ST_SRID(geom)=0 THEN ST_SetSRID(geom,4326)
                 WHEN %s AND ST_SRID(geom)!=4326 THEN ST_Transform(geom,4326)
                 ELSE geom
               END AS geom
        FROM (
            SELECT %s,  -- feature_id_col
                 %s as properties,
                 %s -- geom
            FROM %s %s
          ) t
      ),
      ins AS (
        INSERT INTO ingest.feature_asis
           SELECT *
           FROM scan WHERE geom IS NOT NULL AND ST_IsValid(geom)
        RETURNING 1
      )
      SELECT COUNT(*) FROM ins
    $$,
    q_file_id,
    iif(p_to4326,'true'::text,'false'),  -- decide ST_Transform
    feature_id_col,
    iIF( use_tabcols, 'to_jsonb(subq)'::text, E'\'{}\'::jsonb' ), -- properties
    CASE WHEN lower(p_geom_name)='geom' THEN 'geom' ELSE p_geom_name||' AS geom' END,
    p_tabname,
    iIF( use_tabcols, ', LATERAL (SELECT '|| array_to_string(p_tabcols,',') ||') subq',  ''::text )
  );
  q_query_cad := format(
      $$
      WITH
      scan AS (
        SELECT %s, gid, properties
        FROM (
            SELECT %s,  -- feature_id_col
                 %s as properties
            FROM %s %s
          ) t
      ),
      ins AS (
        INSERT INTO ingest.cadastral_asis
           SELECT *
           FROM scan WHERE properties IS NOT NULL
        RETURNING 1
      )
      SELECT COUNT(*) FROM ins
    $$,
    q_file_id,
    feature_id_col,
    iIF( use_tabcols, 'to_jsonb(subq)'::text, E'\'{}\'::jsonb' ), -- properties
    p_tabname,
    iIF( use_tabcols, ', LATERAL (SELECT '|| array_to_string(p_tabcols,',') ||') subq',  ''::text )
  );

  IF (SELECT ftid::int FROM ingest.feature_type WHERE ftname=lower(p_ftname))<20 THEN -- feature_type id
    EXECUTE q_query_cad INTO num_items;
  ELSE
    EXECUTE q_query INTO num_items;
  END IF;
  msg_ret := format(
    E'From file_id=%s inserted type=%s\nin feature_asis %s items.',
    q_file_id, p_ftname, num_items
  );
  IF num_items>0 THEN
    UPDATE ingest.layer_file
    SET proc_step=2,   -- if insert process occurs after q_query.
        feature_asis_summary= ingest.feature_asis_assign(q_file_id)
    WHERE file_id=q_file_id;
  END IF;
  RETURN msg_ret;
  END;
$f$;
COMMENT ON FUNCTION ingest.any_load(p_method text, p_fileref text, p_ftname text, p_tabname text, p_pck_id real, p_pck_fileref_sha256 text, p_tabcols text[], p_geom_name text, p_to4326 boolean)
  IS 'Load (into ingest.feature_asis) shapefile or any other non-GeoJSON, of a separated table.';
