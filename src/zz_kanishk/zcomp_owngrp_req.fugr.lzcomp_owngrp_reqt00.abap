*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZCOMP_OWNGRP_REQ................................*
DATA:  BEGIN OF STATUS_ZCOMP_OWNGRP_REQ              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZCOMP_OWNGRP_REQ              .
CONTROLS: TCTRL_ZCOMP_OWNGRP_REQ
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZCOMP_OWNGRP_REQ              .
TABLES: ZCOMP_OWNGRP_REQ               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
