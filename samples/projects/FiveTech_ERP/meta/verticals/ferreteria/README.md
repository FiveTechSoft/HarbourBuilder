# Vertical pack: ferreteria

App de **ferretería / bricolaje** (TPV + almacén + clientes).

Se carga cuando la **app de sesión** tiene `vertical: "ferreteria"`  
(empresa con esa app enlazada, o `defaultApp` del usuario).

## Menú

| Sección | Contenido |
|---------|-----------|
| **Clientes** | Parties, ficha, cuentas/talleres, seguimientos |
| **Tienda y almacén** | Artículos, stock, TPV, tarifa |
| **Comercial** | Presupuestos, facturas, import CSV |
| **Administración** | KPIs, agenda, params, cajeros, empresa/app |

## Pantallas / datos (meta base)

| Screen | Data |
|--------|------|
| `screen.products` | `data.products` |
| `screen.stock` | `data.stock` |
| `screen.pos_sales` | `data.pos_sales` |
| `screen.parties` | `data.parties` |
| `screen.quotes` / `screen.invoices` | `data.quotes` / `data.invoices` |

## Enlazar a una empresa

Admin → **Companies** → checklist **Apps (verticals)** → marcar `ferreteria`  
(o campo `apps` / `defaultApp` en `data.companies`).
