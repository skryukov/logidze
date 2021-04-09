CREATE OR REPLACE FUNCTION logidze_append(new_log_data jsonb, changes jsonb, ts timestamp with time zone DEFAULT NULL, history_limit integer DEFAULT NULL, debounce_time integer DEFAULT NULL, columns text[] DEFAULT NULL, include_columns boolean DEFAULT false) RETURNS jsonb AS $body$
  -- version: 1
DECLARE
  version jsonb;
  new_v integer;
  current_version integer;
  size integer;
  iterator integer;
  item record;
BEGIN

  IF ts IS NULL THEN
    ts := statement_timestamp();
  END IF;

  changes = changes - 'log_data';

  IF columns IS NOT NULL THEN
    changes = logidze_filter_keys(changes, columns, include_columns);
  END IF;

  IF changes = '{}' THEN
    RETURN new_log_data;
  END IF;

  current_version := (new_log_data->>'v')::int;

  IF current_version < (new_log_data#>>'{h,-1,v}')::int THEN
    iterator := 0;
    FOR item in SELECT * FROM jsonb_array_elements(new_log_data->'h')
      LOOP
        IF (item.value->>'v')::int > current_version THEN
          new_log_data := jsonb_set(
              new_log_data,
              '{h}',
              (new_log_data->'h') - iterator
            );
        END IF;
        iterator := iterator + 1;
      END LOOP;
  END IF;


  new_v := (new_log_data#>>'{h,-1,v}')::int + 1;

  size := jsonb_array_length(new_log_data->'h');
  version := logidze_version(new_v, changes, ts);

  IF (
      debounce_time IS NOT NULL AND
      (version->>'ts')::bigint - (new_log_data#>'{h,-1,ts}')::text::bigint <= debounce_time
    ) THEN
    -- merge new version with the previous one
    new_v := (new_log_data#>>'{h,-1,v}')::int;
    version := logidze_version(new_v, (new_log_data#>'{h,-1,c}')::jsonb || changes, ts);
    -- remove the previous version from log
    new_log_data := jsonb_set(
        new_log_data,
        '{h}',
        (new_log_data->'h') - (size - 1)
      );
  END IF;

  new_log_data := jsonb_set(
      new_log_data,
      ARRAY['h', size::text],
      version,
      true
    );

  new_log_data := jsonb_set(
      new_log_data,
      '{v}',
      to_jsonb(new_v)
    );

  IF history_limit IS NOT NULL AND history_limit <= size THEN
    new_log_data := logidze_compact_history(new_log_data, size - history_limit + 1);
  END IF;

  RETURN new_log_data;
END;
$body$
LANGUAGE plpgsql;

