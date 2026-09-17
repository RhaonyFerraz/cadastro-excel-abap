*&---------------------------------------------------------------------*
*& Report         ZCLIENTES_EXCEL
*& Descrição:     Cadastro de Clientes via Excel
*&                Lê planilha .xlsx, valida campos obrigatórios e
*&                exibe resultado em ALV Grid (CL_SALV_TABLE).
*&
*& Conceitos ABAP aprendidos:
*&   - Leitura de arquivo Excel (ALSM_EXCEL_TO_INTERNAL_TABLE)
*&   - Diálogo de seleção de arquivo (CL_GUI_FRONTEND_SERVICES)
*&   - Validações de campos obrigatórios
*&   - Validação de CNPJ (algoritmo dos dois dígitos verificadores)
*&   - ALV OO com CL_SALV_TABLE (semáforo, textos, toolbar)
*&
*& Versão:  1.0
*& Data:    2026-09-16
*& Autor:   Projeto cadastro-excel-abap
*&---------------------------------------------------------------------*

REPORT zclientes_excel
  LINE-SIZE 255
  MESSAGE-ID zz.   " <-- ajuste para a message class do seu sistema

*----------------------------------------------------------------------*
* INCLUDES
*----------------------------------------------------------------------*

" Declarações de tipos, tabelas internas e variáveis globais
INCLUDE zclientes_excel_top.

" Tela de seleção e evento AT SELECTION-SCREEN ON VALUE-REQUEST
INCLUDE zclientes_excel_sel.

" Subrotinas (FORMs)
INCLUDE zclientes_excel_sub.

*----------------------------------------------------------------------*
* TEXTOS DE SELEÇÃO (definidos em Transaction SE38 > Goto > Text Elems)
* TEXT-t01 = 'Parâmetros de Entrada'
*----------------------------------------------------------------------*

*----------------------------------------------------------------------*
* EVENTO PRINCIPAL: START-OF-SELECTION
*----------------------------------------------------------------------*

START-OF-SELECTION.

  " 1. Transfere o parâmetro da tela para a variável global
  gv_filepath = p_file.

  " 2. Lê as células do arquivo Excel para gt_excel
  PERFORM f_ler_excel.

  " Interrompe se a planilha estiver vazia
  IF gt_excel IS INITIAL.
    MESSAGE 'Nenhum dado encontrado na planilha. Verifique o arquivo.' TYPE 'S'
            DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " 3. Mapeia as células brutas para registros de clientes em gt_clientes
  PERFORM f_mapear_clientes.

  " Interrompe se nenhum cliente foi mapeado
  IF gt_clientes IS INITIAL.
    MESSAGE 'Nenhum cliente encontrado. Verifique se a planilha possui dados a partir da linha 2.' TYPE 'S'
            DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " 4. Valida campos obrigatórios e CNPJ; preenche STATUS e MSG_ERRO
  PERFORM f_validar_clientes.

  " 5. Exibe o resultado no ALV Grid
  PERFORM f_exibir_alv.
