*----------------------------------------------------------------------*
***INCLUDE LZARC_RECMANF04.
*----------------------------------------------------------------------*

FORM zupdated_on.
  FIELD-SYMBOLS: <fs_field> TYPE any .

*  LOOP AT total.
*    CHECK <action> EQ aendern.
** -- Updated By
*    ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE <vim_total_struc> TO <fs_field>.
*    IF sy-subrc EQ 0.
*      <fs_field> = sy-uname.
*    ENDIF.
** -- Updated On
*    ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE <vim_total_struc> TO <fs_field>.
*    IF sy-subrc EQ 0.
*      <fs_field> = sy-datum.
*    ENDIF.
*    READ TABLE extract WITH KEY <vim_xtotal_key>.
*    IF sy-subrc EQ 0.
*      extract = total.
*      MODIFY extract INDEX sy-tabix.
*    ENDIF.
*    IF total IS NOT INITIAL.
*      MODIFY total.
*    ENDIF.
*  ENDLOOP.


*  IF  zrecman_owners-valid_from IS INITIAL.
*    zrecman_owners-valid_from = sy-datum.
*  ENDIF.
*  IF zrecman_owners-valid_to IS INITIAL.
*    zrecman_owners-valid_to = '99991231'.
*  ENDIF.
*
*  zrecman_owners-created_at = sy-datum.
*  zrecman_owners-created_by = sy-uname.

ENDFORM.
