CLASS y_check_comment_usage DEFINITION PUBLIC INHERITING FROM y_check_base CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor.

  PROTECTED SECTION.
    METHODS execute_check REDEFINITION.
    METHODS inspect_tokens REDEFINITION.

  PRIVATE SECTION.
    DATA leading_structure TYPE sstruc.

    DATA abs_statement_number TYPE i VALUE 0.
    DATA comment_number TYPE i VALUE 0.
    DATA percentage_of_comments TYPE decfloat16 VALUE 0.
    DATA is_function_module TYPE abap_bool.

    METHODS calc_percentage_of_comments.
    METHODS check_leading_structure.

    METHODS is_code_disabled IMPORTING structure     TYPE sstruc
                                       statement     TYPE sstmnt
                             RETURNING VALUE(result) TYPE abap_bool.

    METHODS set_leading_structure IMPORTING structure TYPE sstruc.

ENDCLASS.



CLASS y_check_comment_usage IMPLEMENTATION.


  METHOD constructor.
    super->constructor( ).

    settings-prio = c_note.
    settings-threshold = 10.
    settings-documentation = |{ c_docs_path-checks }comment-usage.md|.

    relevant_statement_types = VALUE #( BASE relevant_statement_types
                                      ( scan_struc_stmnt_type-class_definition )
                                      ( scan_struc_stmnt_type-class_implementation )
                                      ( scan_struc_stmnt_type-interface ) ).

    set_check_message( 'Percentage of comments must be lower than &3% of the productive code! (&2%>=&3%) (&1 lines found)' ).
  ENDMETHOD.


  METHOD execute_check.
    super->execute_check( ).
    check_leading_structure( ).
  ENDMETHOD.


  METHOD inspect_tokens.

    IF leading_structure <> structure.
      check_leading_structure( ).
      set_leading_structure( structure ).
    ENDIF.

    DATA(code_disabled) = is_code_disabled( statement = statement
                                            structure = structure ).

    IF code_disabled = abap_true.
      RETURN.
    ENDIF.

    IF statement-to EQ statement-from.
      abs_statement_number = abs_statement_number + 1.
    ELSE.
      abs_statement_number = abs_statement_number + ( statement-to - statement-from ).
    ENDIF.

    LOOP AT ref_scan_manager->tokens ASSIGNING FIELD-SYMBOL(<token>)
    FROM statement-from TO statement-to
    WHERE type EQ scan_token_type-comment.

      IF strlen( <token>-str ) GE 2 AND NOT
         ( <token>-str+0(2) EQ |*"| OR
           <token>-str+0(2) EQ |"!| OR
           <token>-str+0(2) EQ |##| OR
           <token>-str+0(2) EQ |*?| OR
           <token>-str+0(2) EQ |"?| OR
           ( strlen( <token>-str ) GE 3 AND <token>-str+0(3) EQ |"#E| ) OR
           <token>-str CP '"' && object_name && '*.' ).   "#EC CI_MAGIC
        comment_number = comment_number + 1.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD check_leading_structure.

    CHECK leading_structure IS NOT INITIAL.

    calc_percentage_of_comments( ).

    DATA(statement_for_message) = ref_scan_manager->statements[ leading_structure-stmnt_from ].

    DATA(check_configuration) = detect_check_configuration( error_count = round( val = percentage_of_comments
                                                                                 dec = 0
                                                                                 mode = cl_abap_math=>round_down )
                                                            statement = statement_for_message ).

    IF check_configuration IS INITIAL.
      RETURN.
    ENDIF.

    raise_error( statement_level     = statement_for_message-level
                 statement_index     = leading_structure-stmnt_from
                 statement_from      = statement_for_message-from
                 error_priority      = check_configuration-prio
                 parameter_01        = |{ comment_number }|
                 parameter_02        = |{ percentage_of_comments }|
                 parameter_03        = |{ check_configuration-threshold }| ).

  ENDMETHOD.


  METHOD calc_percentage_of_comments.
    percentage_of_comments = ( comment_number / abs_statement_number ) * 100.
    percentage_of_comments = round( val = percentage_of_comments dec = 2 ).
  ENDMETHOD.


  METHOD is_code_disabled.
    CHECK structure-stmnt_type EQ scan_struc_stmnt_type-function.

    IF get_token_abs( statement-from ) EQ if_kaizen_keywords_c=>gc_function.
      is_function_module = abap_true.
    ELSEIF get_token_abs( statement-from ) EQ if_kaizen_keywords_c=>gc_endfunction.
      is_function_module = abap_false.
    ENDIF.

    result = xsdbool( is_function_module EQ abap_false ).
  ENDMETHOD.


  METHOD set_leading_structure.
    leading_structure = structure.

    abs_statement_number = 0.
    comment_number = 0.
    percentage_of_comments = 0.
  ENDMETHOD.


ENDCLASS.
