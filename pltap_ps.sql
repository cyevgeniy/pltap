-- Copyright(c) 2019-2021 Yevgeniy Chaban <ychbn@ychbn.com>
--
-- Permission to use, copy, modify, distribute, and sell this software and its
-- documentation for any purpose is hereby granted without fee, provided that
-- the above copyright notice appear in all copies and that both that
-- copyright notice and this permission notice appear in supporting
-- documentation.  No representations are made about the suitability of this
-- software for any purpose.  It is provided "as is" without express or
-- implied warranty.
create or replace package pltap as

type t_pltap_output is
    table of varchar2(4000);
procedure set_output_to_table;

procedure set_output_to_screen;

procedure set_description(
    pdescription varchar2);

procedure start_test(
    pdescription varchar2 default null
);

procedure start_test (
    pplan_count number,
    pdescription varchar2 default null
);

procedure end_test;

procedure set_date_format (
    pdate_format varchar2
);

procedure fail (
    pmessage varchar2
);

procedure pass (
    pmessage varchar2
);

procedure print (
    poutput t_pltap_output,
    pdescription varchar2 default null
);

procedure ok (
    pcondition     boolean,
    pdescription   varchar2 default null
);

procedure eq (
    pgot           number,
    pwant          number,
    pdescription   varchar2 default null
);

procedure eq (
    pgot           varchar2,
    pwant          varchar2,
    pdescription   varchar2 default null
);

procedure eq (
    pgot           date,
    pwant          date,
    pdescription   varchar2 default null
);

procedure eq(
    pgot           blob,
    pwant          blob,
    pdescription   varchar2 default null
);

procedure neq (
    pgot           number,
    pwant          number,
    pdescription   varchar2 default null
);

procedure neq (
    pgot           varchar2,
    pwant          varchar2,
    pdescription   varchar2 default null
);

procedure neq (
    pgot           date,
    pwant          date,
    pdescription   varchar2 default null
);

procedure results_eq (
    pqry_1         varchar2,
    pqry_2         varchar2,
    pdescription   varchar2 default null
);

procedure results_eq (
    pcursor_1      sys_refcursor,
    pcursor_2      sys_refcursor,
    pdescription   varchar2 default null
);

procedure bulk_run(
    powner varchar2,
    pprocedure_name varchar2
);

END pltap;
/
