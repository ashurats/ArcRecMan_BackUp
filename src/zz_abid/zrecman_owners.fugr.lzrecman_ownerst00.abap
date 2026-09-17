*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZRECMAN_OWNERS..................................*
DATA:  BEGIN OF STATUS_ZRECMAN_OWNERS                .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZRECMAN_OWNERS                .
CONTROLS: TCTRL_ZRECMAN_OWNERS
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZRECMAN_OWNERS                .
TABLES: ZRECMAN_OWNERS                 .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
