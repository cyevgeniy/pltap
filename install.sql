-- Copyright(c) 2019-2021 Yevgeniy Chaban <ychbn@ychbn.com>
--
-- Permission to use, copy, modify, distribute, and sell this software and its
-- documentation for any purpose is hereby granted without fee, provided that
-- the above copyright notice appear in all copies and that both that
-- copyright notice and this permission notice appear in supporting
-- documentation.  No representations are made about the suitability of this
-- software for any purpose.  It is provided "as is" without express or
-- implied warranty.
prompt Pltap testing package will be installed on current schema
prompt If you want to cancel install, press Ctrl-C now
prompt Press Enter to continue installation
pause

@@uninstall.sql

@@pltap_ddl.sql
@@pltap_ps.sql
@@pltap_pb.sql

show err
