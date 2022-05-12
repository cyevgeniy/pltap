create or replace package body pltap as

    type t_failed_ids is
        table of number;
    c_output_table          constant number := 1;
    c_output_screen         constant number := 2;
    g_output                number := c_output_screen;
    g_count_ok              number;
    g_start_test_time       timestamp;
    g_end_test_time         timestamp;
    g_test_id               number;
    g_plan_count            number := null;
    g_date_format           varchar2(100) := 'dd.mm.yyyy hh24:mi:ss';
    g_failed_ids            t_failed_ids := t_failed_ids();
    g_failed_bulks          t_pltap_output := t_pltap_output();
    g_current_description   varchar2(4000) := null;

    procedure set_description (
        pdescription varchar2
    ) is
    begin
        g_current_description := pdescription;
    end;

    procedure print_to_screen (
        poutput t_pltap_output
    ) is
    begin
        for i in 1..poutput.count loop
            dbms_output.put_line(poutput(i));
        end loop;
    end;

    procedure print_to_table (
        poutput        t_pltap_output,
        pdescription   varchar2 default null
    ) is
        pragma autonomous_transaction;
    begin
        for i in 1..poutput.count loop insert into pltap_results (
            output_text,
            description
        ) values (
            poutput(i),
            pdescription
        );

        end loop;

        commit;
    end;

    procedure set_date_format (
        pdate_format varchar2
    ) is
    begin
        g_date_format := pdate_format;
    end;

    procedure set_output_to_table is
    begin
        g_output := c_output_table;
    end;

    procedure set_output_to_screen is
    begin
        g_output := c_output_screen;
    end;

    procedure print (
        poutput        t_pltap_output,
        pdescription   varchar2 default null
    ) is
    begin
        if g_output = c_output_table then
            print_to_table(poutput, nvl(pdescription, g_current_description));
        elsif g_output = c_output_screen then
            print_to_screen(poutput);
        end if;
    end;

    function get_string_hash (
        str varchar2
    ) return varchar2 is
        res varchar2(4000) := '';
    begin
        res := dbms_utility.get_hash_value(name => str, base => 1000000000, hash_size => power(2, 30));

        return ltrim(to_char(res, lpad('X', 30, 'X')));
    end;

    function clob_hash (
        str clob
    ) return varchar2 is

        l_orig_str      clob;
        l_c_portion     constant number := 4000;
        l_portion_str   varchar2(4000);
        res             varchar2(4000) := '';
    begin
        l_orig_str := str;
        while length(l_orig_str) > l_c_portion loop
            l_portion_str := substr(l_orig_str, 1, l_c_portion);
            l_orig_str := substr(l_orig_str, l_c_portion + 1);
            res := res || get_string_hash(l_portion_str);
        end loop;

        res := res || get_string_hash(l_orig_str);
        return res;
    end;

    function get_refcursor_hash (
        pcursor sys_refcursor
    ) return varchar2 is

        res              varchar2(4000);
        l_cursor         sys_refcursor := pcursor;
        l_cursor_id      number;
        l_column_count   number;
        l_desctab        dbms_sql.desc_tab;
        l_numvar         number;
        l_strvar         varchar2(4000);
        l_datevar        date;
        l_qry_result     clob := to_clob('');
    begin
      -- Switch from native dynamic SQL to DBMS_SQL package:
        l_cursor_id := dbms_sql.to_cursor_number(l_cursor);
        dbms_sql.describe_columns(l_cursor_id, l_column_count, l_desctab);

      -- Define columns:
        for i in 1..l_column_count loop if l_desctab(i).col_type = 2 then
            dbms_sql.define_column(l_cursor_id, i, l_numvar);
        elsif l_desctab(i).col_type = 12 then
            dbms_sql.define_column(l_cursor_id, i, l_datevar);
          -- statements
        else
            dbms_sql.define_column(l_cursor_id, i, l_strvar, 4000);
        end if;
        end loop;

      -- Fetch rows with DBMS_SQL package:

        while dbms_sql.fetch_rows(l_cursor_id) > 0 loop
            for i in 1..l_column_count loop if ( l_desctab(i).col_type in (
                1,
                96
            ) ) then
                dbms_sql.column_value(l_cursor_id, i, l_strvar);
                l_qry_result := l_qry_result || l_strvar;
            elsif ( l_desctab(i).col_type = 2 ) then
                dbms_sql.column_value(l_cursor_id, i, l_numvar);
                l_qry_result := l_qry_result || to_char(l_numvar);
            elsif ( l_desctab(i).col_type = 12 ) then
                dbms_sql.column_value(l_cursor_id, i, l_datevar);
                l_qry_result := l_qry_result || to_char(l_datevar, 'dd.mm.yyyy hh24:mi:ss');
            end if;
            end loop;

            l_qry_result := l_qry_result || '-';
        end loop;

        dbms_sql.close_cursor(l_cursor_id);
        res := clob_hash(l_qry_result);
        return res;
    end;

    function get_query_hash (
        pqry varchar2
    ) return varchar2 is
        res        varchar2(4000);
        l_cursor   sys_refcursor;
    begin
        open l_cursor for pqry;

        res := get_refcursor_hash(l_cursor);
        return res;
    end;

    function get_diffs (
        pgot        varchar2,
        pexpected   varchar2
    ) return t_pltap_output is
        l_res t_pltap_output := t_pltap_output();
    begin
        l_res.extend(2);
        l_res(1) := '# Expected: '
                    || case
            when pexpected is null then
                '''''(Empty string)'
            else ''''
                 || pexpected
                 || ''''
        end;

        l_res(2) := '# Got: '
                    || case
            when pgot is null then
                '''''(Empty string)'
            else ''''
                 || pgot
                 || ''''
        end;

        return l_res;
    end;

    procedure print_diffs (
        pgot        varchar2,
        pexpected   varchar2
    ) is
    begin
        print(get_diffs(pgot, pexpected));
    end;

    function get_diffs (
        pgot        number,
        pexpected   number
    ) return t_pltap_output is
        l_res t_pltap_output := t_pltap_output();
    begin
        l_res.extend(2);
        l_res(1) := '# Expected:'
                    || case
            when pexpected is null then
                '(null)'
            else to_char(pexpected)
        end;

        l_res(2) := '# Got: '
                    || case
            when pgot is null then
                '(null)'
            else to_char(pgot)
        end;

        return l_res;
    end;

    procedure print_diffs (
        pgot        number,
        pexpected   number
    ) is
    begin
        print(get_diffs(pgot, pexpected));
    end;

    function get_diffs (
        pgot        date,
        pexpected   date
    ) return t_pltap_output is
        l_res t_pltap_output := t_pltap_output();
    begin
        l_res.extend(2);
        l_res(1) := '# Expected: '
                    || case
            when pexpected is null then
                '(null)'
            else to_char(pexpected, g_date_format)
        end;

        l_res(2) := '# Got: '
                    || case
            when pgot is null then
                '(null)'
            else to_char(pgot, g_date_format)
        end;

        return l_res;
    end;

    procedure print_diffs (
        pgot        date,
        pexpected   date
    ) is
    begin
        print(get_diffs(pgot, pexpected));
    end;

    procedure results_eq (
        pqry_1         varchar2,
        pqry_2         varchar2,
        pdescription   varchar2 default null
    ) is
    begin
        ok(get_query_hash(pqry_1) = get_query_hash(pqry_2), pdescription);
    end;

    procedure results_eq (
        pcursor_1      sys_refcursor,
        pcursor_2      sys_refcursor,
        pdescription   varchar2 default null
    ) is
    begin
        ok(get_refcursor_hash(pcursor_1) = get_refcursor_hash(pcursor_2), pdescription);
    end;

    function get_timestamp_diff (
        ptimestamp_1   timestamp,
        ptimestamp_2   timestamp
    ) return t_pltap_output is
        l_res t_pltap_output := t_pltap_output();
    begin
        l_res.extend;
        select
            extract(hour from timestamp_diff.diff)
            || ' hours '
            || extract(minute from timestamp_diff.diff)
            || ' minutes '
            || trim(to_char(round(extract(second from timestamp_diff.diff), 3), '999990D999'))
            || ' seconds'
        into l_res(1)
        from
            (
                select ptimestamp_1 - ptimestamp_2 diff
                from
                    dual
            ) timestamp_diff;

        return l_res;
    end;

    procedure print_timestamp_diff (
        timestamp_1   timestamp,
        timestamp_2   timestamp
    ) is
    begin
        print(get_timestamp_diff(timestamp_1, timestamp_2), g_current_description);
    end;

    function get_percentage_result (
        pcount_ok      number,
        pcount_notok   number
    ) return number is
        l_result number;
    begin
        begin
            l_result := round(nvl(pcount_ok, 0) / nvl((pcount_notok + pcount_ok), 0) * 100, 2);
        exception
            when zero_divide then
                l_result := 0;
        end;

        return l_result;
    end;

    function get_results (
        pcount_ok       number,
        pfailed_ids     t_failed_ids,
        pfailed_bulks   t_pltap_output
    ) return t_pltap_output is

        l_res                t_pltap_output := t_pltap_output();
        -- I Hope we do not reach 4000 limit in string with failed tests
        l_failed_tests_str   varchar2(4000) := '';
        l_idx                number;
        -- Last index before extending if pfailed_bulks isn't empty
        l_last_idx           number;
    begin
        l_idx := pfailed_ids.first;
        while ( l_idx is not null ) loop
            l_failed_tests_str := l_failed_tests_str
                                  ||
                case
                    when l_failed_tests_str is null then
                        ''
                    else ','
                end
                                  || pfailed_ids(l_idx);

            l_idx := pfailed_ids.next(l_idx);
        end loop;

        if pfailed_ids.count > 0 then
            l_res.extend;
            l_res(l_res.last) := 'FAILED: ' || l_failed_tests_str;
        end if;

        l_res.extend;
        l_res(l_res.last) := 'Failed '
                             || pfailed_ids.count
                             || '/'
                             || ( pfailed_ids.count + pcount_ok )
                             || ' '
                             || get_percentage_result(pcount_ok, pfailed_ids.count)
                             || '% ok';

        if pfailed_bulks.count > 0 then
            l_last_idx := l_res.last;
            l_res.extend(1 + pfailed_bulks.count);
            l_res(l_last_idx + 1) := 'WARNING: Some packages weren''t tested because of exceptions in theirs test procedures:';
            for i in 1..pfailed_bulks.count loop l_res(l_last_idx + 1 + i) := pfailed_bulks(i);
            end loop;

        end if;

        return l_res;
    end;

    procedure print_results (
        pcount_ok       number,
        pfailed_ids     t_failed_ids,
        pfailed_bulks   t_pltap_output
    ) is
    begin
        print(get_results(pcount_ok, pfailed_ids, pfailed_bulks), g_current_description);
    end;

    procedure start_test (
        pdescription varchar2 default null
    ) as
    begin
        g_start_test_time := current_timestamp;
        g_count_ok := 0;
        g_test_id := 0;
        g_failed_ids.delete;
        g_failed_bulks.delete;
        set_description(pdescription);
    end start_test;

    function get_plan_count (
        pplan_count number
    ) return t_pltap_output is
        l_res t_pltap_output := t_pltap_output();
    begin
        l_res.extend;
        l_res(1) := '1..' || pplan_count;
        return l_res;
    end;

    procedure start_test (
        pplan_count    number,
        pdescription   varchar2 default null
    ) is
    begin
        start_test(pdescription);
        g_plan_count := pplan_count;
        print(get_plan_count(g_plan_count), g_current_description);
    end;

    procedure end_test as
    begin
        g_end_test_time := current_timestamp;
        print_results(g_count_ok, g_failed_ids, g_failed_bulks);
        print_timestamp_diff(g_end_test_time, g_start_test_time);
    end end_test;

    function get_ok (
        ptest_id       number,
        pdescription   varchar2
    ) return t_pltap_output is
        l_res t_pltap_output := t_pltap_output();
    begin
        l_res.extend;
        l_res(1) := 'ok '
                    || ptest_id
                    || ' '
                    || pdescription;
        return l_res;
    end;

    procedure pass (
        pmessage varchar2
    ) is
    begin
        g_count_ok := g_count_ok + 1;
        g_test_id := g_test_id + 1;
        print(get_ok(g_test_id, pmessage));
    end;

    function get_notok (
        ptest_id       number,
        pdescription   varchar2
    ) return t_pltap_output is
        l_res t_pltap_output := t_pltap_output();
    begin
        l_res.extend;
        l_res(1) := 'not ok: '
                    || ptest_id
                    || ' '
                    || pdescription;
        return l_res;
    end;

    procedure fail (
        pmessage varchar2
    ) is
    begin
        g_test_id := g_test_id + 1;
        g_failed_ids.extend;
        g_failed_ids(g_failed_ids.last) := g_test_id;
        print(get_notok(g_test_id, pmessage));
    end;

    procedure ok (
        pcondition     boolean,
        pdescription   varchar2 default null
    ) is
    begin
        if pcondition then
            pass(pdescription);
        else
            fail(pdescription);
        end if;
    end;

    procedure eq (
        pgot           number,
        pwant          number,
        pdescription   varchar2 default null
    ) is
        l_result boolean;
    begin
        l_result := ( pgot = pwant );
        ok(l_result, pdescription);
        if not l_result or l_result is null then
            print_diffs(pgot, pwant);
        end if;
    end;

    procedure eq (
        pgot           varchar2,
        pwant          varchar2,
        pdescription   varchar2 default null
    ) is
        l_result boolean;
    begin
        l_result := ( pgot = pwant );
        ok(l_result, pdescription);
        if not l_result or l_result is null then
            print_diffs(pgot, pwant);
        end if;
    end;

    procedure eq (
        pgot           date,
        pwant          date,
        pdescription   varchar2 default null
    ) is
        l_result boolean;
    begin
        l_result := ( pgot = pwant );
        ok(l_result, pdescription);
        if not l_result or l_result is null then
            print_diffs(pgot, pwant);
        end if;
    end;

    procedure eq(
        pgot           blob,
        pwant          blob,
        pdescription   varchar2 default null
    ) is
        l_comp number;
    begin
        l_comp := dbms_lob.compare(pgot, pwant);

        ok(l_comp=0, pdescription);
    end;

    procedure neq (
        pgot           number,
        pwant          number,
        pdescription   varchar2 default null
    ) is
    begin
        ok((pgot <> pwant), pdescription);
    end;

    procedure neq (
        pgot           varchar2,
        pwant          varchar2,
        pdescription   varchar2 default null
    ) is
    begin
        ok((pgot <> pwant), pdescription);
    end;

    procedure neq (
        pgot           date,
        pwant          date,
        pdescription   varchar2 default null
    ) is
    begin
        ok((pgot <> pwant), pdescription);
    end;

    procedure bulk_run (
        powner            varchar2,
        pprocedure_name   varchar2
    ) is
        l_statement_to_execute   clob := '';
        l_buf                    t_pltap_output := t_pltap_output();
    begin
        for test_procedure in (
            select
                ap.owner,
                ap.object_name,
                ap.procedure_name
            from
                all_procedures ap
            where
                ap.owner = trim(upper(powner))
                and ap.procedure_name = trim(upper(pprocedure_name))
        ) loop
            l_statement_to_execute := 'begin'
                                      || chr(13)
                                      || test_procedure.owner
                                      || '.'
                                      || test_procedure.object_name
                                      || '.'
                                      || test_procedure.procedure_name
                                      || ';'
                                      || 'end;';

            begin
                execute immediate l_statement_to_execute;
            exception
                when others then
                    g_failed_bulks.extend;
                    g_failed_bulks(g_failed_bulks.last) := test_procedure.owner
                                                           || '.'
                                                           || test_procedure.object_name
                                                           || '.'
                                                           || test_procedure.procedure_name
                                                           || '('
                                                           || sqlerrm
                                                           || ')';

            end;

        end loop;
    end;

end pltap;
/