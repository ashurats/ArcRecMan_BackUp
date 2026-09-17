*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZRECMAN_ADMIN...................................*
DATA:  BEGIN OF STATUS_ZRECMAN_ADMIN                 .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZRECMAN_ADMIN                 .
CONTROLS: TCTRL_ZRECMAN_ADMIN
            TYPE TABLEVIEW USING SCREEN '0001'.
*...processing: ZRECMAN_SETTINGS................................*
DATA:  BEGIN OF STATUS_ZRECMAN_SETTINGS              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZRECMAN_SETTINGS              .
*...processing: ZRECMAN_SUSER...................................*
DATA:  BEGIN OF STATUS_ZRECMAN_SUSER                 .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZRECMAN_SUSER                 .
CONTROLS: TCTRL_ZRECMAN_SUSER
            TYPE TABLEVIEW USING SCREEN '0003'.
*...processing: ZREC_APPROVERS..................................*
DATA:  BEGIN OF STATUS_ZREC_APPROVERS                .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZREC_APPROVERS                .
CONTROLS: TCTRL_ZREC_APPROVERS
            TYPE TABLEVIEW USING SCREEN '0100'.
*...processing: ZROLE_APPROVERS.................................*
DATA:  BEGIN OF STATUS_ZROLE_APPROVERS               .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZROLE_APPROVERS               .
CONTROLS: TCTRL_ZROLE_APPROVERS
            TYPE TABLEVIEW USING SCREEN '0002'.
*.........table declarations:.................................*
TABLES: *ZRECMAN_ADMIN                 .
TABLES: *ZRECMAN_SETTINGS              .
TABLES: *ZRECMAN_SUSER                 .
TABLES: *ZREC_APPROVERS                .
TABLES: *ZROLE_APPROVERS               .
TABLES: ZRECMAN_ADMIN                  .
TABLES: ZRECMAN_SETTINGS               .
TABLES: ZRECMAN_SUSER                  .
TABLES: ZREC_APPROVERS                 .
TABLES: ZROLE_APPROVERS                .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
