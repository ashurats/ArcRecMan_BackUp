*-------------------------------------------------------------------------------------------*
* Titel   : Z_ARC_RECMAN                                                                    *
*-------------------------------------------------------------------------------------------*
* Copyright  (c) 2025 Archon Meridian GbR, Deutschland All rights reserved                  *
*                                                                                           *
* Projekt : SAP Role Recertification Manager (“ArcRecMan”)                                  *
*                                                                                           *
* Autor  : Uwe Schlegel                                                                     *
*                                                                                           *
* Beschreibung: Diese Anwendung wird vom Autorisierungsadministrator verwendet.             *
*              Wenn der Autorisierungsadministrator mit dieser Anwendung eine neue          *
*              Sammelrolle erstellt, wird ein automatischer Genehmigungsworkflow ausgelöst. *
*              Alle Benutzer, die derzeit eine der in der neuen Sammelrolle enthaltenen     *
*              Einzelrollen innehaben, erhalten eine E-Mail-Benachrichtigung.               *
*              In dieser E-Mail werden sie um ihre Zustimmung oder Ablehnung gebeten und    *
*              erhalten eine Begründung des Administrators für die Kombination der Rollen.  *
*                                                                                           *
*-------------------------------------------------------------------------------------------*
*    Dev.          DATE            Description                                              *
*-------------------------------------------------------------------------------------------*
*   <ALIABID>   20250630  Zusammengesetzte Rollenerstellung mit Workflow E-Mail Genehmigung *
*                         durch die Rolleninhaber und Rollentransport                       *
*-------------------------------------------------------------------------------------------*
* HISTORIE ÄNDERN                                                                           *
*-------------------------------------------------------------------------------------------*
* Dev.          DARUM          Beschreibung                                                 *
*-------------------------------------------------------------------------------------------*
REPORT z_arc_recman_demo.


DATA: ok_code TYPE sy-ucomm,
      save_ok TYPE sy-ucomm.

DATA: it_actgrp   TYPE TABLE OF agr_txt,
      it_actgrp1  TYPE TABLE OF agr_txt,
      it_bapiret  TYPE TABLE OF bapiret2,
      it_bapiret2 TYPE TABLE OF bapiret2,
      it_bapiret3 TYPE TABLE OF bapiret2.

DATA: lt_bal_t_msg TYPE STANDARD TABLE OF bal_s_msg.

DATA: itab_1   TYPE TABLE OF zagr_agrs,
      ls_tab_1 TYPE zagr_agrs,
      itab_2   TYPE TABLE OF zagr_agrs.
TABLES: agr_agrs, zagr_agrs, agr_texts, zcomp_role_hdr.

*---------------------------------------------------------------------------------*
"<-- Kontrolle auf autorisierten Benutzer, der das Programm ausführen darf
*---------------------------------------------------------------------------------*

SELECT * FROM zrecman_admin INTO TABLE @DATA(lt_recman_admin). "#CI_NOWHERE

READ TABLE lt_recman_admin ASSIGNING FIELD-SYMBOL(<fs_recman_admin>) WITH KEY admin = sy-uname.
IF sy-subrc IS NOT INITIAL.
  MESSAGE e005(zz_arc_recman).
  EXIT.
ENDIF.

CALL SCREEN 001.

FORM dequeue_lock.

  CALL FUNCTION 'DEQUEUE_EZAGR_AGRS'
    EXPORTING
*     mode_agr_agrs = 'E'              " Lock mode for table AGR_AGRS
      mandt    = sy-mandt         " Enqueue argument 01
      agr_name = agr_agrs-agr_name                " Enqueue argument 02
*     child_agr     =                  " Enqueue argument 03
*     x_agr_name    = space            " Fill argument 02 with initial value?
*     x_child_agr   = space            " Fill argument 03 with initial value?
*     _scope   = '3'
*     _synchron     = space            " Synchonous unlock
*     _collect = ' '              " Initially only collect lock
    .

ENDFORM.

FORM enqueue_lock.
*  DATA: lv_subrc TYPE sy-subrc.
*  " Example: Lock one record
  READ TABLE itab_1 INTO zagr_agrs INDEX 1.
**  READ TABLE itab_1 INTO ezfire_req INDEX recman-current_line.
*  IF sy-subrc = 0.
  TRY.
      CALL FUNCTION 'ENQUEUE_EZAGR_AGRS'
        EXPORTING
*         MODE_AGR_AGRS  = 'X'
          mandt          = sy-mandt
          agr_name       = agr_agrs-agr_name
*         CHILD_AGR      =
*         X_AGR_NAME     = ' '
*         X_CHILD_AGR    = ' '
*         _SCOPE         = '2'
*         _WAIT          = ' '
*         _COLLECT       = ' '
        EXCEPTIONS
          foreign_lock   = 1
          system_failure = 2
          OTHERS         = 3.
      IF sy-subrc <> 0.
        CASE sy-subrc.
          WHEN 1.
            MESSAGE e010(zz_arc_recman) WITH agr_agrs-agr_name.
          WHEN 2.
            MESSAGE e011(zz_arc_recman).
          WHEN OTHERS.
            MESSAGE e008(zz_arc_recman).
        ENDCASE.
      ENDIF.
    CATCH cx_sy_no_handler INTO DATA(lx_err).
      MESSAGE lx_err->get_text( ) TYPE 'E'.
  ENDTRY.

ENDFORM.
*&---------------------------------------------------------------------*
*& Module STATUS_0001 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0001 OUTPUT.
  SET PF-STATUS 'STATUS_0001'.
  SET TITLEBAR 'TITLE'.
  SELECT SINGLE text FROM agr_texts INTO zagr_agrs-agr_name_descr ##WARN_OK
    WHERE agr_name = agr_agrs-agr_name
      AND spras EQ sy-langu.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0001  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0001 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.
  CASE save_ok.
    WHEN 'BACK'.
      LEAVE PROGRAM.
    WHEN 'CREATE'.
      IF agr_agrs-agr_name IS INITIAL.
        MESSAGE e000(zz_arc_recman) DISPLAY LIKE 'E'.
      ENDIF.

      SELECT *
        FROM agr_agrs
        INTO CORRESPONDING FIELDS OF TABLE @itab_1 ##TOO_MANY_ITAB_FIELDS
        WHERE agr_name = @agr_agrs-agr_name.
      IF sy-subrc EQ 0.
        MESSAGE e003(zz_arc_recman) DISPLAY LIKE 'I' WITH agr_agrs-agr_name.
        LEAVE SCREEN.
      ELSE.
*----------------------------------------------------------------------------------------------------------------*
* Lock-Objekte wurden verwendet, um den Zugriff auf dieselben Daten durch mehrere Programme zu synchronisieren.
*----------------------------------------------------------------------------------------------------------------*
        PERFORM enqueue_lock.
*          CALL SCREEN 100.
        CALL SCREEN 101.
      ENDIF.

    WHEN 'CHANGE'.
      IF agr_agrs-agr_name IS INITIAL.
        MESSAGE e000(zz_arc_recman) DISPLAY LIKE 'E'.
      ENDIF.
      IF itab_1 IS INITIAL.
        SELECT *
              FROM agr_agrs
              INTO CORRESPONDING FIELDS OF TABLE @itab_1 ##TOO_MANY_ITAB_FIELDS
              WHERE agr_name = @agr_agrs-agr_name.
        IF sy-subrc IS NOT INITIAL.
          MESSAGE e018(zz_arc_recman) DISPLAY LIKE 'E' WITH agr_agrs-agr_name.
        ENDIF.
      ENDIF.
*----------------------------------------------------------------------------------------------------------------*
* Lock-Objekte wurden verwendet, um den Zugriff auf dieselben Daten durch mehrere Programme zu synchronisieren.
*----------------------------------------------------------------------------------------------------------------*
      PERFORM enqueue_lock.
*          CALL SCREEN 100.
      CALL SCREEN 101.
  ENDCASE.
ENDMODULE.
