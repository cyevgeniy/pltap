CREATE OR REPLACE PACKAGE pltap AS
    TYPE t_pltap_output IS
        TABLE OF VARCHAR2(4000);
    PROCEDURE set_output_to_table;

    PROCEDURE set_output_to_screen;

    procedure set_description(
        pdescription varchar2);

    PROCEDURE start_test(
        pdescription varchar2 default null
    );

    PROCEDURE start_test (
        pplan_count NUMBER,
        pdescription varchar2 default null
    );

    PROCEDURE end_test;

    PROCEDURE set_date_format (
        pdate_format VARCHAR2
    );

    PROCEDURE fail (
        pmessage VARCHAR2
    );

    PROCEDURE pass (
        pmessage VARCHAR2
    );

    PROCEDURE print (
        poutput t_pltap_output,
        pdescription VARCHAR2 default null
    );

    PROCEDURE ok (
        pcondition     BOOLEAN,
        pdescription   VARCHAR2 DEFAULT NULL
    );

    PROCEDURE eq (
        pgot           NUMBER,
        pwant          NUMBER,
        pdescription   VARCHAR2 DEFAULT NULL
    );

    PROCEDURE eq (
        pgot           VARCHAR2,
        pwant          VARCHAR2,
        pdescription   VARCHAR2 DEFAULT NULL
    );

    PROCEDURE eq (
        pgot           DATE,
        pwant          DATE,
        pdescription   VARCHAR2 DEFAULT NULL
    );

    PROCEDURE neq (
        pgot           NUMBER,
        pwant          NUMBER,
        pdescription   VARCHAR2 DEFAULT NULL
    );

    PROCEDURE neq (
        pgot           VARCHAR2,
        pwant          VARCHAR2,
        pdescription   VARCHAR2 DEFAULT NULL
    );

    PROCEDURE neq (
        pgot           DATE,
        pwant          DATE,
        pdescription   VARCHAR2 DEFAULT NULL
    );

    PROCEDURE results_eq (
        pqry_1         VARCHAR2,
        pqry_2         VARCHAR2,
        pdescription   VARCHAR2 DEFAULT NULL
    );

    PROCEDURE results_eq (
        pcursor_1      SYS_REFCURSOR,
        pcursor_2      SYS_REFCURSOR,
        pdescription   VARCHAR2 DEFAULT NULL
    );

END pltap;