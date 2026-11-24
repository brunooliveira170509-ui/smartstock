/* ============================================================
   SmartStock – Script do banco de dados (PostgreSQL 16)
   Autor: Bruno de Oliveira · Atividade 6
   ============================================================ */

-- Tipo enumerado para o tipo de movimentação
CREATE TYPE tipo_movimentacao AS ENUM ('ENTRADA', 'SAIDA');

/* ------------------------------------------------------------
   Tabela PRODUTO
   ------------------------------------------------------------ */
CREATE TABLE produto (
    id              SERIAL        PRIMARY KEY,
    nome            VARCHAR(150)  NOT NULL,
    categoria       VARCHAR(80)   NOT NULL,
    quantidade      INTEGER       NOT NULL DEFAULT 0 CHECK (quantidade >= 0),   -- RN-01
    estoque_minimo  INTEGER       NOT NULL DEFAULT 1 CHECK (estoque_minimo >= 0),
    preco           NUMERIC(12,2) NOT NULL CHECK (preco >= 0),
    data_cadastro   TIMESTAMP     NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_produto_nome UNIQUE (nome)
);

/* ------------------------------------------------------------
   Tabela MOVIMENTACAO
   ------------------------------------------------------------ */
CREATE TABLE movimentacao (
    id          SERIAL             PRIMARY KEY,
    produto_id  INTEGER            NOT NULL
                REFERENCES produto (id) ON DELETE RESTRICT,                  -- RN-04
    tipo        tipo_movimentacao  NOT NULL,
    quantidade  INTEGER            NOT NULL CHECK (quantidade > 0),          -- RN-05
    data        TIMESTAMP          NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_produto_categoria   ON produto (categoria);
CREATE INDEX ix_movimentacao_data   ON movimentacao (data DESC);
CREATE INDEX ix_movimentacao_prod   ON movimentacao (produto_id);

/* ------------------------------------------------------------
   Trigger: atualiza o saldo do produto a cada movimentação
   (RN-02 – o saldo só muda por movimentações)
   ------------------------------------------------------------ */
CREATE OR REPLACE FUNCTION fn_atualiza_saldo()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tipo = 'ENTRADA' THEN
        UPDATE produto SET quantidade = quantidade + NEW.quantidade
         WHERE id = NEW.produto_id;
    ELSE
        UPDATE produto SET quantidade = quantidade - NEW.quantidade
         WHERE id = NEW.produto_id;          -- o CHECK (quantidade >= 0) barra saldo negativo
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_atualiza_saldo
AFTER INSERT ON movimentacao
FOR EACH ROW EXECUTE FUNCTION fn_atualiza_saldo();

/* ------------------------------------------------------------
   View: situação de cada produto (RN-03)
   ------------------------------------------------------------ */
CREATE VIEW vw_situacao_estoque AS
SELECT p.id, p.nome, p.categoria, p.quantidade, p.estoque_minimo,
       p.preco, (p.quantidade * p.preco) AS valor_total,
       CASE WHEN p.quantidade = 0                 THEN 'ZERADO'
            WHEN p.quantidade <= p.estoque_minimo THEN 'BAIXO'
            ELSE 'OK' END AS situacao
  FROM produto p;

/* ------------------------------------------------------------
   Carga inicial de exemplo (autopeças)
   ------------------------------------------------------------ */
INSERT INTO produto (nome, categoria, quantidade, estoque_minimo, preco) VALUES
 ('Óleo Motor 5W30 Sintético 1L', 'Lubrificantes', 0, 24, 42.90),
 ('Filtro de Óleo Tecfil PSL55',  'Filtros',       0, 15, 27.50),
 ('Pastilha de Freio Cobreq',     'Freios',        0, 10, 89.00),
 ('Vela de Ignição NGK',          'Ignição',       0, 40, 21.90),
 ('Palheta Limpador Bosch 21"',   'Acessórios',    0, 12, 54.90),
 ('Bateria Moura 60Ah',           'Elétrica',      0,  4, 589.00);

INSERT INTO movimentacao (produto_id, tipo, quantidade) VALUES
 (1,'ENTRADA',60),(1,'SAIDA',41),
 (2,'ENTRADA',30),(2,'SAIDA',22),
 (3,'ENTRADA',20),(3,'SAIDA',6),
 (4,'ENTRADA',100),(4,'SAIDA',35),
 (5,'ENTRADA',12),(5,'SAIDA',12),
 (6,'ENTRADA',8), (6,'SAIDA',3);
