CREATE OR REPLACE PACKAGE BODY pltap AS

    TYPE t_failed_ids IS
        TABLE OF NUMBER;
    c_output_table      CONSTANT NUMBER := 1;
    c_output_screen     CONSTANT NUMBER := 2;
    g_output            NUMBER := c_output_screen;
    g_count_ok          NUMBER;
    g_start_test_time   TIMESTAMP;
    g_end_test_time     TIMESTAMP;
    g_test_id           NUMBER;
    g_plan_count        NUMBER := NULL;
    g_date_format       VARCHAR2(100) := 'dd.mm.yyyy hh24:mi:ss';
    g_failed_ids        t_failed_ids := t_failed_ids();
    g_current_description varchar2(4000) := null;

    procedure set_description(
        pdescription varchar2
    ) is
    begin
        g_current_description := pdescription;
    end;

    PROCEDURE print_to_screen (
        poutput t_pltap_output
    ) IS
    BEGIN
        FOR i IN 1..poutput.count LOOP
            dbms_output.put_line(poutput(i));
        END LOOP;
    END;

    PROCEDURE print_to_table (
        poutput t_pltap_output,
        pdescription varchar2 default null
    ) IS
    PRAGMA autonomous_transaction;
    BEGIN
        FOR i IN 1..poutput.count LOOP
            INSERT INTO pltap_results ( output_text, description )
            VALUES ( poutput(i), pdescription );
        END LOOP;
        commit;
    END;

    PROCEDURE set_date_format (
        pdate_format VARCHAR2
    ) IS
    BEGIN
        g_date_format := pdate_format;
    END;

    PROCEDURE set_output_to_table IS
    BEGIN
        g_output := c_output_table;
    END;

    PROCEDURE set_output_to_screen IS
    BEGIN
        g_output := c_output_screen;
    END;

    PROCEDURE print (
        poutput t_pltap_output,
        pdescription varchar2 default null
    ) IS
    BEGIN
        IF g_output = c_output_table THEN
            print_to_table(poutput, nvl(pdescription, g_current_description) );
        ELSIF g_output = c_output_screen THEN
            print_to_screen(poutput);
        END IF;
    END;

    FUNCTION get_string_hash (
        str VARCHAR2
    ) RETURN VARCHAR2 IS
        res VARCHAR2(4000) := '';
    BEGIN
        res := dbms_utility.get_hash_value(name => str, base => 1000000000, hash_size => power(2, 30));

        RETURN ltrim(to_char(res, lpad('X', 30, 'X')));
    END;

    FUNCTION clob_hash (
        str CLOB
    ) RETURN VARCHAR2 IS

        l_orig_str      CLOB;
        l_c_portion     CONSTANT NUMBER := 4000;
        l_portion_str   VARCHAR2(4000);
        res             VARCHAR2(4000) := '';
    BEGIN
        l_orig_str := str;
        WHILE length(l_orig_str) > l_c_portion LOOP
            l_portion_str := substr(l_orig_str, 1, l_c_portion);
            l_orig_str := substr(l_orig_str, l_c_portion + 1);
            res := res || get_string_hash(l_portion_str);
        END LOOP;

        res := res || get_string_hash(l_orig_str);
        RETURN res;
    END;

    FUNCTION get_refcursor_hash (
        pcursor SYS_REFCURSOR
    ) RETURN VARCHAR2 IS

        res              VARCHAR2(4000);
        l_cursor         SYS_REFCURSOR := pcursor;
        l_cursor_id      NUMBER;
        l_column_count   NUMBER;
        l_desctab        dbms_sql.desc_tab;
        l_numvar         NUMBER;
        l_strvar         VARCHAR2(4000);
        l_datevar        DATE;
        l_qry_result     CLOB := to_clob('');
    BEGIN
      -- Switch from native dynamic SQL to DBMS_SQL package:
        l_cursor_id := dbms_sql.to_cursor_number(l_cursor);
        dbms_sql.describe_columns(l_cursor_id, l_column_count, l_desctab);

      -- Define columns:
        FOR i IN 1..l_column_count LOOP IF l_desctab(i).col_type = 2 THEN
            dbms_sql.define_column(l_cursor_id, i, l_numvar);
        ELSIF l_desctab(i).col_type = 12 THEN
            dbms_sql.define_column(l_cursor_id, i, l_datevar);
          -- statements
        ELSE
            dbms_sql.define_column(l_cursor_id, i, l_strvar, 4000);
        END IF;
        END LOOP;

      -- Fetch rows with DBMS_SQL package:

        WHILE dbms_sql.fetch_rows(l_cursor_id) > 0 LOOP
            FOR i IN 1..l_column_count LOOP IF ( l_desctab(i).col_type in (1, 96) ) THEN
                dbms_sql.column_value(l_cursor_id, i, l_strvar);
                l_qry_result := l_qry_result || l_strvar;
            ELSIF ( l_desctab(i).col_type = 2 ) THEN
                dbms_sql.column_value(l_cursor_id, i, l_numvar);
                l_qry_result := l_qry_result || to_char(l_numvar);
            ELSIF ( l_desctab(i).col_type = 12 ) THEN
                dbms_sql.column_value(l_cursor_id, i, l_datevar);
                l_qry_result := l_qry_result || to_char(l_datevar, 'dd.mm.yyyy hh24:mi:ss');
            END IF;
            END LOOP;

            l_qry_result := l_qry_result || '-';
        END LOOP;

        dbms_sql.close_cursor(l_cursor_id);
        res := clob_hash(l_qry_result);
        RETURN res;
    END;

    FUNCTION get_query_hash (
        pqry VARCHAR2
    ) RETURN VARCHAR2 IS
        res        VARCHAR2(4000);
        l_cursor   SYS_REFCURSOR;
    BEGIN
        OPEN l_cursor FOR pqry;

        res := get_refcursor_hash(l_cursor);
        RETURN res;
    END;

    FUNCTION get_diffs (
        pgot        VARCHAR2,
        pexpected   VARCHAR2
    ) RETURN t_pltap_output IS
        l_res t_pltap_output := t_pltap_output();
    BEGIN
        l_res.extend(2);
        l_res(1) := '# Expected: '
                    || CASE
            WHEN pexpected IS NULL THEN
                '''''(Empty string)'
            ELSE ''''
                 || pexpected
                 || ''''
        END;

        l_res(2) := '# Got: '
                    || CASE
            WHEN pgot IS NULL THEN
                '''''(Empty string)'
            ELSE ''''
                 || pgot
                 || ''''
        END;

        RETURN l_res;
    END;

    PROCEDURE print_diffs (
        pgot        VARCHAR2,
        pexpected   VARCHAR2
    ) IS
    BEGIN
        print(get_diffs(pgot, pexpected));
    END;

    FUNCTION get_diffs (
        pgot        NUMBER,
        pexpected   NUMBER
    ) RETURN t_pltap_output IS
        l_res t_pltap_output := t_pltap_output();
    BEGIN
        l_res.extend(2);
        l_res(1) := '# Expected:'
                    || CASE
            WHEN pexpected IS NULL THEN
                '(Null)'
            ELSE to_char(pexpected)
        END;

        l_res(2) := '# Got: '
                    || CASE
            WHEN pgot IS NULL THEN
                '(Null)'
            ELSE to_char(pgot)
        END;

        RETURN l_res;
    END;

    PROCEDURE print_diffs (
        pgot        NUMBER,
        pexpected   NUMBER
    ) IS
    BEGIN
        print(get_diffs(pgot, pexpected));
    END;

    FUNCTION get_diffs (
        pgot        DATE,
        pexpected   DATE
    ) RETURN t_pltap_output IS
        l_res t_pltap_output := t_pltap_output();
    BEGIN
        l_res.extend(2);
        l_res(1) := '# Expected: '
                    || CASE
            WHEN pexpected IS NULL THEN
                '(Null)'
            ELSE to_char(pexpected, g_date_format)
        END;

        l_res(2) := '# Got: '
                    || CASE
            WHEN pgot IS NULL THEN
                '(Null)'
            ELSE to_char(pgot, g_date_format)
        END;

        RETURN l_res;
    END;

    PROCEDURE print_diffs (
        pgot        DATE,
        pexpected   DATE
    ) IS
    BEGIN
        print(get_diffs(pgot, pexpected));
    END;

    PROCEDURE results_eq (
        pqry_1         VARCHAR2,
        pqry_2         VARCHAR2,
        pdescription   VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        ok(get_query_hash(pqry_1) = get_query_hash(pqry_2), pdescription);
    END;

    PROCEDURE results_eq (
        pcursor_1      SYS_REFCURSOR,
        pcursor_2      SYS_REFCURSOR,
        pdescription   VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        ok(get_refcursor_hash(pcursor_1) = get_refcursor_hash(pcursor_2), pdescription);
    END;

    FUNCTION get_timestamp_diff (
        ptimestamp_1   TIMESTAMP,
        ptimestamp_2   TIMESTAMP
    ) RETURN t_pltap_output IS
        l_res t_pltap_output := t_pltap_output();
    BEGIN
        l_res.extend;
        SELECT
            EXTRACT(HOUR FROM timestamp_diff.diff)
            || ' hours '
            || EXTRACT(MINUTE FROM timestamp_diff.diff)
            || ' minutes '
            || trim(to_char(round(EXTRACT(SECOND FROM timestamp_diff.diff), 3), '999990D999'))
            || ' seconds'
        INTO
            l_res
        (1)
        FROM
            (
                SELECT
                    ptimestamp_1 - ptimestamp_2 diff
                FROM
                    dual
            ) timestamp_diff;

        RETURN l_res;
    END;

    PROCEDURE print_timestamp_diff (
        timestamp_1   TIMESTAMP,
        timestamp_2   TIMESTAMP
    ) IS
    BEGIN
        print(get_timestamp_diff(timestamp_1, timestamp_2), g_current_description);
    END;

    FUNCTION get_percentage_result (
        pcount_ok      NUMBER,
        pcount_notok   NUMBER
    ) RETURN NUMBER IS
        l_result NUMBER;
    BEGIN
        BEGIN
            l_result := round(nvl(pcount_ok, 0) / nvl((pcount_notok + pcount_ok), 0) * 100, 2);
        EXCEPTION
            WHEN zero_divide THEN
                l_result := 0;
        END;

        RETURN l_result;
    END;

    FUNCTION get_results (
        pcount_ok     NUMBER,
        pfailed_ids   t_failed_ids
    ) RETURN t_pltap_output IS
        l_res                t_pltap_output := t_pltap_output();
        -- I Hope we do not reach 4000 limit in string with failed tests
        l_failed_tests_str   VARCHAR2(4000) := '';
        l_idx                NUMBER;
    BEGIN
        l_idx := pfailed_ids.first;
        WHILE ( l_idx IS NOT NULL ) LOOP
            l_failed_tests_str := l_failed_tests_str
                                  ||
                CASE
                    WHEN l_failed_tests_str IS NULL THEN
                        ''
                    ELSE ','
                END
                                  || pfailed_ids(l_idx);

            l_idx := pfailed_ids.next(l_idx);
        END LOOP;

        IF pfailed_ids.count > 0 THEN
            l_res.extend;
            l_res(l_res.last) := 'FAILED: ' || l_failed_tests_str;
        END IF;

        l_res.extend;
        l_res(l_res.last) := 'Failed '
                             || pfailed_ids.count
                             || '/'
                             || ( pfailed_ids.count + pcount_ok )
                             || ' '
                             || get_percentage_result(pcount_ok, pfailed_ids.count)
                             || '% ok';

        RETURN l_res;
    END;

    PROCEDURE print_results (
        pcount_ok     NUMBER,
        pfailed_ids   t_failed_ids
    ) IS
    BEGIN
        print(get_results(pcount_ok, pfailed_ids), g_current_description);
    END;

    PROCEDURE start_test(
        pdescription varchar2 default null
    ) AS
    BEGIN
        g_start_test_time := current_timestamp;
        g_count_ok := 0;
        g_test_id := 0;
        g_failed_ids.DELETE;
        set_description(pdescription);
    END start_test;

    FUNCTION get_plan_count (
        pplan_count NUMBER
    ) RETURN t_pltap_output IS
        l_res t_pltap_output := t_pltap_output();
    BEGIN
        l_res.extend;
        l_res(1) := '1..' || pplan_count;
        RETURN l_res;
    END;

    PROCEDURE start_test (
        pplan_count NUMBER,
        pdescription varchar2 default null
    ) IS
    BEGIN
        start_test(pdescription);
        g_plan_count := pplan_count;
        print(get_plan_count(g_plan_count), g_current_description);
    END;

    PROCEDURE end_test AS
    BEGIN
        g_end_test_time := current_timestamp;
        print_results(g_count_ok, g_failed_ids);
        print_timestamp_diff(g_end_test_time, g_start_test_time);
    END end_test;

    FUNCTION get_ok (
        ptest_id       NUMBER,
        pdescription   VARCHAR2
    ) RETURN t_pltap_output IS
        l_res t_pltap_output := t_pltap_output();
    BEGIN
        l_res.extend;
        l_res(1) := 'ok '
                    || ptest_id
                    || ' '
                    || pdescription;
        RETURN l_res;
    END;

    PROCEDURE pass (
        pmessage VARCHAR2
    ) IS
    BEGIN
        g_count_ok := g_count_ok + 1;
        g_test_id := g_test_id + 1;
        print(get_ok(g_test_id, pmessage));
    END;

    FUNCTION get_notok (
        ptest_id       NUMBER,
        pdescription   VARCHAR2
    ) RETURN t_pltap_output IS
        l_res t_pltap_output := t_pltap_output();
    BEGIN
        l_res.extend;
        l_res(1) := 'not ok: '
                    || ptest_id
                    || ' '
                    || pdescription;
        RETURN l_res;
    END;

    PROCEDURE fail (
        pmessage VARCHAR2
    ) IS
    BEGIN
        g_test_id := g_test_id + 1;
        g_failed_ids.extend;
        g_failed_ids(g_failed_ids.last) := g_test_id;
        print(get_notok(g_test_id, pmessage));
    END;

    PROCEDURE ok (
        pcondition     BOOLEAN,
        pdescription   VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        IF pcondition THEN
            pass(pdescription);
        ELSE
            fail(pdescription);
        END IF;
    END;

    PROCEDURE eq (
        pgot           NUMBER,
        pwant          NUMBER,
        pdescription   VARCHAR2 DEFAULT NULL
    ) IS
        l_result BOOLEAN;
    BEGIN
        l_result := ( pgot = pwant );
        ok(l_result, pdescription);
        IF NOT l_result OR l_result IS NULL THEN
            print_diffs(pgot, pwant);
        END IF;
    END;

    PROCEDURE eq (
        pgot           VARCHAR2,
        pwant          VARCHAR2,
        pdescription   VARCHAR2 DEFAULT NULL
    ) IS
        l_result BOOLEAN;
    BEGIN
        l_result := ( pgot = pwant );
        ok(l_result, pdescription);
        IF NOT l_result OR l_result IS NULL THEN
            print_diffs(pgot, pwant);
        END IF;
    END;

    PROCEDURE eq (
        pgot           DATE,
        pwant          DATE,
        pdescription   VARCHAR2 DEFAULT NULL
    ) IS
        l_result BOOLEAN;
    BEGIN
        l_result := ( pgot = pwant );
        ok(l_result, pdescription);
        IF NOT l_result OR l_result IS NULL THEN
            print_diffs(pgot, pwant);
        END IF;
    END;

    PROCEDURE neq (
        pgot           NUMBER,
        pwant          NUMBER,
        pdescription   VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        ok((pgot <> pwant), pdescription);
    END;

    PROCEDURE neq (
        pgot           VARCHAR2,
        pwant          VARCHAR2,
        pdescription   VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        ok((pgot <> pwant), pdescription);
    END;

    PROCEDURE neq (
        pgot           DATE,
        pwant          DATE,
        pdescription   VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        ok((pgot <> pwant), pdescription);
    END;

    PROCEDURE bulk_run(
        powner VARCHAR2,
        pprocedure_name VARCHAR2
    ) IS
        l_statement_to_execute clob := '';-- := 'begin' || chr(13) || 'null;';
    BEGIN
        for test_procedure in (
            select ap.owner, ap.object_name, ap.procedure_name
            from all_procedures ap
            where ap.owner = trim(upper(powner))
            and ap.procedure_name = trim(upper(pprocedure_name)))
        loop
            l_statement_to_execute := l_statement_to_execute
                || test_procedure.owner
                || '.'
                || test_procedure.object_name
                || '.'
                || test_procedure.procedure_name
                || ';';
        end loop;

        if l_statement_to_execute is not null then
            l_statement_to_execute := 'begin'
                || chr(13)
                || l_statement_to_execute
                || chr(13)
                || 'end;';
        end if;

        execute immediate l_statement_to_execute;

    END;

END pltap;

/