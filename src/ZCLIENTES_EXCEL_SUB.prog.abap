*&---------------------------------------------------------------------*
*& Include          ZCLIENTES_EXCEL_SUB
*& Descrição:       Subrotinas (FORMs) do programa:
*&                    - Browse de arquivo
*&                    - Leitura do Excel
*&                    - Mapeamento de colunas
*&                    - Validação de campos
*&                    - Validação de CNPJ (algoritmo oficial)
*&                    - Exibição do ALV
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& FORM f_browse_arquivo
*& Abre o diálogo de seleção de arquivo para o usuário escolher o .xlsx
*&---------------------------------------------------------------------*
FORM f_browse_arquivo.

  DATA: lt_filetable TYPE filetable,   " Tabela de arquivos retornados
        ls_filetable TYPE file_table,  " Linha individual de arquivo
        lv_rc        TYPE i,           " Return code do diálogo
        lv_action    TYPE i.           " Ação do usuário (OK/Cancel)

  " Abre o diálogo de browse no lado do presentation server (PC do usuário)
  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title            = 'Selecionar Planilha Excel'
      default_extension       = 'xlsx'
      file_filter             = 'Arquivos Excel (*.xlsx)|*.xlsx|Todos (*.*)|*.*|'
      multiselection          = abap_false   " Somente um arquivo por vez
    CHANGING
      file_table              = lt_filetable
      rc                      = lv_rc
      user_action             = lv_action
    EXCEPTIONS
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      not_supported_by_gui    = 4
      OTHERS                  = 5.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao abrir diálogo de seleção de arquivo.' TYPE 'E'.
    RETURN.
  ENDIF.

  " Usuário clicou em "Abrir" (não cancelou)
  IF lv_action = cl_gui_frontend_services=>action_ok.
    READ TABLE lt_filetable INTO ls_filetable INDEX 1.
    IF sy-subrc = 0.
      p_file = ls_filetable-filename.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_ler_excel
*& Lê o arquivo Excel usando a RFC ALSM_EXCEL_TO_INTERNAL_TABLE.
*& Essa RFC converte as células do Excel em uma tabela interna.
*&---------------------------------------------------------------------*
FORM f_ler_excel.

  " ALSM_EXCEL_TO_INTERNAL_TABLE retorna cada célula individualmente
  " com linha, coluna e valor. Veja a estrutura ty_excel_cell no TOP.
  CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
    EXPORTING
      filename                = gv_filepath
      i_begin_col             = 1    " Coluna inicial (A)
      i_begin_row             = 1    " Linha inicial (inclui cabeçalho)
      i_end_col               = 6    " Coluna final (F): Nome,CNPJ,End,Cidade,UF,CEP
      i_end_row               = 9999 " Lê até 9999 linhas
    TABLES
      intern                  = gt_excel
    EXCEPTIONS
      inconsistent_parameters = 1
      upload_ole              = 2
      OTHERS                  = 3.

  IF sy-subrc <> 0.
    MESSAGE |Erro ao ler o arquivo: { gv_filepath }| TYPE 'E'.
    RETURN.
  ENDIF.

  " Verifica se alguma célula foi retornada
  IF gt_excel IS INITIAL.
    MESSAGE 'A planilha está vazia ou o formato é inválido.' TYPE 'W'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_mapear_clientes
*& Converte a tabela de células brutas do Excel (gt_excel)
*& em registros estruturados de clientes (gt_clientes).
*& A linha 1 é o cabeçalho e será ignorada.
*&---------------------------------------------------------------------*
FORM f_mapear_clientes.

  DATA: ls_excel   TYPE ty_excel_cell,
        lv_linha   TYPE i VALUE 0.    " Linha atual sendo processada

  CLEAR gt_clientes.

  LOOP AT gt_excel INTO ls_excel.

    " Ignora a linha de cabeçalho (linha 1 da planilha)
    IF ls_excel-row = 1.
      CONTINUE.
    ENDIF.

    " Detecta nova linha: inicializa work area
    IF ls_excel-row <> lv_linha.
      " Salva o cliente anterior (exceto na primeira iteração)
      IF lv_linha > 1.
        APPEND gs_cliente TO gt_clientes.
        CLEAR gs_cliente.
      ENDIF.
      lv_linha        = ls_excel-row.
      gs_cliente-linha = ls_excel-row.
    ENDIF.

    " Mapeia cada coluna para o campo correspondente
    " Colunas: 1=Nome 2=CNPJ 3=Endereço 4=Cidade 5=UF 6=CEP
    CASE ls_excel-col.
      WHEN 1. gs_cliente-nome     = CONV string( ls_excel-value ).
      WHEN 2. gs_cliente-cnpj     = CONV string( ls_excel-value ).
      WHEN 3. gs_cliente-endereco = CONV string( ls_excel-value ).
      WHEN 4. gs_cliente-cidade   = CONV string( ls_excel-value ).
      WHEN 5. gs_cliente-uf       = CONV char2( ls_excel-value ).
      WHEN 6. gs_cliente-cep      = CONV string( ls_excel-value ).
    ENDCASE.

  ENDLOOP.

  " Adiciona o último cliente processado
  IF lv_linha > 1 AND gs_cliente IS NOT INITIAL.
    APPEND gs_cliente TO gt_clientes.
    CLEAR gs_cliente.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_validar_clientes
*& Percorre gt_clientes e aplica as regras de validação:
*&   1. NOME é obrigatório
*&   2. CNPJ é obrigatório e deve ter 14 dígitos válidos
*&   3. ENDEREÇO é obrigatório
*& Preenche os campos STATUS e MSG_ERRO de cada registro.
*&---------------------------------------------------------------------*
FORM f_validar_clientes.

  DATA: lv_erros   TYPE string,
        lv_valido  TYPE abap_bool.

  LOOP AT gt_clientes INTO gs_cliente.

    CLEAR: lv_erros.
    lv_valido = abap_true.

    "--- Validação 1: Nome obrigatório ---
    IF gs_cliente-nome IS INITIAL.
      lv_valido = abap_false.
      lv_erros = |{ lv_erros }[NOME vazio] |.
    ENDIF.

    "--- Validação 2: CNPJ obrigatório e formato ---
    IF gs_cliente-cnpj IS INITIAL.
      lv_valido = abap_false.
      lv_erros = |{ lv_erros }[CNPJ vazio] |.
    ELSE.
      " Remove formatação (pontos, barras, hífen) antes de validar
      DATA(lv_cnpj_limpo) = gs_cliente-cnpj.
      REPLACE ALL OCCURRENCES OF '.' IN lv_cnpj_limpo WITH ''.
      REPLACE ALL OCCURRENCES OF '/' IN lv_cnpj_limpo WITH ''.
      REPLACE ALL OCCURRENCES OF '-' IN lv_cnpj_limpo WITH ''.

      DATA(lv_cnpj_valido) = abap_false.
      PERFORM f_validar_cnpj USING lv_cnpj_limpo CHANGING lv_cnpj_valido.

      IF lv_cnpj_valido = abap_false.
        lv_valido = abap_false.
        lv_erros = |{ lv_erros }[CNPJ inválido: { gs_cliente-cnpj }] |.
      ELSE.
        " Armazena o CNPJ limpo (só dígitos)
        gs_cliente-cnpj = lv_cnpj_limpo.
      ENDIF.
    ENDIF.

    "--- Validação 3: Endereço obrigatório ---
    IF gs_cliente-endereco IS INITIAL.
      lv_valido = abap_false.
      lv_erros = |{ lv_erros }[ENDEREÇO vazio] |.
    ENDIF.

    "--- Atribui status visual ---
    IF lv_valido = abap_true.
      gs_cliente-status   = gc_icon_ok.
      gs_cliente-msg_erro = 'Registro válido'.
    ELSE.
      gs_cliente-status   = gc_icon_error.
      gs_cliente-msg_erro = lv_erros.
    ENDIF.

    MODIFY gt_clientes FROM gs_cliente.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_validar_cnpj
*& Implementa o algoritmo oficial de validação de CNPJ brasileiro.
*& Parâmetros:
*&   iv_cnpj    - CNPJ com apenas 14 dígitos numéricos (sem formatação)
*&   ev_valido  - ABAP_TRUE se o CNPJ for matematicamente válido
*&---------------------------------------------------------------------*
FORM f_validar_cnpj
  USING    iv_cnpj   TYPE string
  CHANGING ev_valido TYPE abap_bool.

  DATA: lv_soma  TYPE i,
        lv_resto TYPE i,
        lv_dig1  TYPE i,
        lv_dig2  TYPE i,
        lv_char  TYPE c,
        lv_num   TYPE i,
        lv_peso  TYPE i,
        lv_len   TYPE i.

  ev_valido = abap_false.

  " CNPJ deve ter exatamente 14 dígitos
  lv_len = strlen( iv_cnpj ).
  IF lv_len <> 14.
    RETURN.
  ENDIF.

  " Verifica se todos os caracteres são dígitos
  DO 14 TIMES.
    lv_char = iv_cnpj+( sy-index - 1 )(1).
    IF lv_char CA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ !@#$%^&*()-+=/'.
      RETURN.
    ENDIF.
  ENDDO.

  " Rejeita CNPJs com todos os dígitos iguais (ex: 11111111111111)
  DATA(lv_todos_iguais) = abap_true.
  DO 13 TIMES.
    IF iv_cnpj+( sy-index - 1 )(1) <> iv_cnpj+0(1).
      lv_todos_iguais = abap_false.
      EXIT.
    ENDIF.
  ENDDO.
  IF lv_todos_iguais = abap_true.
    RETURN.
  ENDIF.

  "---------- Cálculo do 1º dígito verificador ----------
  " Pesos: 5,4,3,2,9,8,7,6,5,4,3,2 (para os 12 primeiros dígitos)
  DATA(lt_pesos1) = VALUE int4_table( ( 5 ) ( 4 ) ( 3 ) ( 2 )
                                      ( 9 ) ( 8 ) ( 7 ) ( 6 )
                                      ( 5 ) ( 4 ) ( 3 ) ( 2 ) ).
  lv_soma = 0.
  DO 12 TIMES.
    lv_char = iv_cnpj+( sy-index - 1 )(1).
    lv_num  = CONV i( lv_char ).
    READ TABLE lt_pesos1 INTO lv_peso INDEX sy-index.
    lv_soma = lv_soma + ( lv_num * lv_peso ).
  ENDDO.

  lv_resto = lv_soma MOD 11.
  IF lv_resto < 2.
    lv_dig1 = 0.
  ELSE.
    lv_dig1 = 11 - lv_resto.
  ENDIF.

  " Compara com o 13º dígito da string
  lv_char = iv_cnpj+12(1).
  IF CONV i( lv_char ) <> lv_dig1.
    RETURN.   " 1º dígito verificador não confere
  ENDIF.

  "---------- Cálculo do 2º dígito verificador ----------
  " Pesos: 6,5,4,3,2,9,8,7,6,5,4,3,2 (para os 13 primeiros dígitos)
  DATA(lt_pesos2) = VALUE int4_table( ( 6 ) ( 5 ) ( 4 ) ( 3 ) ( 2 )
                                      ( 9 ) ( 8 ) ( 7 ) ( 6 )
                                      ( 5 ) ( 4 ) ( 3 ) ( 2 ) ).
  lv_soma = 0.
  DO 13 TIMES.
    lv_char = iv_cnpj+( sy-index - 1 )(1).
    lv_num  = CONV i( lv_char ).
    READ TABLE lt_pesos2 INTO lv_peso INDEX sy-index.
    lv_soma = lv_soma + ( lv_num * lv_peso ).
  ENDDO.

  lv_resto = lv_soma MOD 11.
  IF lv_resto < 2.
    lv_dig2 = 0.
  ELSE.
    lv_dig2 = 11 - lv_resto.
  ENDIF.

  " Compara com o 14º dígito da string
  lv_char = iv_cnpj+13(1).
  IF CONV i( lv_char ) <> lv_dig2.
    RETURN.   " 2º dígito verificador não confere
  ENDIF.

  " Se chegou aqui, o CNPJ é matematicamente válido
  ev_valido = abap_true.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_exibir_alv
*& Monta e exibe o ALV Grid usando a classe CL_SALV_TABLE (ALV OO).
*& Configura colunas, textos, funções e cores de linha.
*&---------------------------------------------------------------------*
FORM f_exibir_alv.

  "---------- Criação do objeto ALV ----------
  TRY.
    cl_salv_table=>factory(
      IMPORTING
        r_salv_table = go_alv
      CHANGING
        t_table      = gt_clientes ).

  CATCH cx_salv_msg INTO gx_salv_error.
    MESSAGE gx_salv_error->get_text( ) TYPE 'E'.
    RETURN.
  ENDTRY.

  "---------- Funções Padrão (toolbar) ----------
  " Ativa todos os botões padrão do ALV: exportar, ordenar, filtrar, etc.
  go_functions = go_alv->get_functions( ).
  go_functions->set_all( abap_true ).

  "---------- Configurações de Display ----------
  go_display = go_alv->get_display_settings( ).
  go_display->set_list_header( 'Cadastro de Clientes — Resultado da Importação' ).
  go_display->set_striped_pattern( cl_salv_display_settings=>true ).

  "---------- Configuração de Colunas ----------
  go_columns = go_alv->get_columns( ).
  go_columns->set_optimize( abap_true ).  " Ajuste automático de largura

  " Torna a coluna STATUS não editável e com texto curto
  PERFORM f_configurar_coluna
    USING 'STATUS'   'St.'  'Status'        'Status de Validação'  4.

  " Configura cada coluna com textos em PT-BR
  PERFORM f_configurar_coluna
    USING 'LINHA'    'Lin.' 'Linha'         'Linha da Planilha'    5.
  PERFORM f_configurar_coluna
    USING 'MSG_ERRO' 'Msg'  'Mensagem'      'Resultado / Mensagem de Erro' 40.
  PERFORM f_configurar_coluna
    USING 'NOME'     'Nome' 'Razão Social'  'Nome / Razão Social'  40.
  PERFORM f_configurar_coluna
    USING 'CNPJ'     'CNPJ' 'CNPJ'          'CNPJ (14 dígitos)'   14.
  PERFORM f_configurar_coluna
    USING 'ENDERECO' 'End.' 'Endereço'      'Logradouro / Endereço' 50.
  PERFORM f_configurar_coluna
    USING 'CIDADE'   'Cid.' 'Cidade'        'Cidade'               30.
  PERFORM f_configurar_coluna
    USING 'UF'       'UF'   'UF'            'Unidade Federativa'   2.
  PERFORM f_configurar_coluna
    USING 'CEP'      'CEP'  'CEP'           'CEP'                  8.

  "---------- Exibição ----------
  go_alv->display( ).

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_configurar_coluna
*& Aplica textos e largura a uma coluna do ALV.
*&---------------------------------------------------------------------*
FORM f_configurar_coluna
  USING iv_campo    TYPE lvc_fname  " Nome do campo na tabela interna
        iv_short    TYPE string     " Texto curto da coluna
        iv_medium   TYPE string     " Texto médio da coluna
        iv_long     TYPE string     " Texto longo (tooltip / cabeçalho expandido)
        iv_largura  TYPE lvc_outlen. " Largura em caracteres

  TRY.
    go_column = CAST cl_salv_column_table(
                  go_columns->get_column( iv_campo ) ).

    go_column->set_short_text(  CONV #( iv_short  ) ).
    go_column->set_medium_text( CONV #( iv_medium ) ).
    go_column->set_long_text(   CONV #( iv_long   ) ).
    go_column->set_output_length( iv_largura ).

  CATCH cx_salv_not_found.
    " Coluna não encontrada — ignora silenciosamente
  ENDTRY.

ENDFORM.
