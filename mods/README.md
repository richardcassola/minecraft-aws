# Mods — Guia de Instalação (Fabric)

O servidor já vem com **Fabric Server** instalado automaticamente pelo `setup.sh`. Você só precisa adicionar os arquivos `.jar` dos mods.

## Como funciona

- O Fabric é um mod loader leve e compatível com a maioria dos mods modernos
- Mods server-side rodam apenas no servidor — os jogadores não precisam instalar nada
- Mods que alteram conteúdo (itens, blocos, etc.) precisam ser instalados **no servidor e no cliente**

## Onde baixar mods

| Site | URL |
|------|-----|
| Modrinth | https://modrinth.com/mods?l=fabric&e=server |
| CurseForge | https://www.curseforge.com/minecraft/mc-mods?filter-game-version=fabric |

Sempre verifique:
- Compatibilidade com a **versão do Minecraft** instalada no servidor
- Se o mod é para **Fabric** (não Forge/NeoForge)
- Se é **server-side** ou requer instalação no cliente também

## Como instalar um mod

### 1. Conectar no servidor via SSM

```bash
aws ssm start-session --target <instance_id> --region us-east-1
```

### 2. Baixar o mod

```bash
cd /opt/minecraft/mods
sudo curl -L -o nome-do-mod.jar "URL_DO_DOWNLOAD"
```

### 3. Reiniciar o servidor

```bash
sudo systemctl restart minecraft
```

### 4. Verificar logs

```bash
sudo journalctl -u minecraft -f
```

Se o mod carregou corretamente, aparecerá nos logs de inicialização.

## Exemplo: instalar Lithium (otimização de performance)

```bash
aws ssm start-session --target <instance_id> --region us-east-1

# Baixar do Modrinth (substitua pela URL da versão correta)
cd /opt/minecraft/mods
sudo curl -L -o lithium.jar "https://modrinth.com/mod/lithium/versions?l=fabric"

# Reiniciar
sudo systemctl restart minecraft
```

## Remover um mod

```bash
sudo rm /opt/minecraft/mods/nome-do-mod.jar
sudo systemctl restart minecraft
```

## Mods recomendados (server-side, performance)

| Mod | Descrição |
|-----|-----------|
| [Lithium](https://modrinth.com/mod/lithium) | Otimiza game logic (tick, pathfinding, etc.) |
| [Starlight](https://modrinth.com/mod/starlight) | Reescreve o motor de iluminação |
| [FerriteCore](https://modrinth.com/mod/ferrite-core) | Reduz uso de memória |

Esses mods são 100% server-side — jogadores não precisam instalar nada.
