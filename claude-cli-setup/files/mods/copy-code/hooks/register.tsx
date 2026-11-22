import type { Register } from 'claude-code'

type Block = { key: string; n: number; label: string; code: string; end: number }
type Parsed = { lines: string[]; blocks: Block[] }

// Parsing is keyed by the reply block's text: the render site carries no id,
// and the same text always parses to the same blocks.
const cache = new Map<string, Parsed>()
const CACHE_MAX = 300

function hash(s: string): string {
  let h = 5381
  for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0
  return (h >>> 0).toString(36)
}

function parse(text: string): Parsed {
  const hit = cache.get(text)
  if (hit) return hit
  const blocks: Block[] = []
  const lines = text.split('\n')
  const id = hash(text)
  let i = 0
  while (i < lines.length) {
    const open = /^( {0,3})(`{3,}|~{3,})\s*([^\s`]*)/.exec(lines[i] ?? '')
    if (!open) { i++; continue }
    const indent = open[1] ?? ''
    const fence = open[2] ?? '```'
    const lang = open[3] ?? ''
    const body: string[] = []
    i++
    while (i < lines.length) {
      const line = lines[i] ?? ''
      if (new RegExp(`^ {0,3}${fence[0]}{${fence.length},}\\s*$`).test(line)) break
      body.push(indent ? line.replace(new RegExp(`^ {0,${indent.length}}`), '') : line)
      i++
    }
    const end = Math.min(i, lines.length - 1) // the closing fence's line
    i++
    const code = body.join('\n')
    const first = (body.find(l => l.trim() !== '') ?? '').trim()
    const head = first.length > 32 ? `${first.slice(0, 31)}…` : first
    const n = blocks.length + 1
    blocks.push({ key: `copy-${id}-${n}`, n, end, code, label: `Copy ${n}${lang ? ` ${lang}` : ''}${head ? `: ${head}` : ''}` })
  }
  const parsed = { lines, blocks }
  if (cache.size >= CACHE_MAX) cache.delete(cache.keys().next().value as string)
  cache.set(text, parsed)
  return parsed
}

export const register: Register = on => {
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.props.isSummary) return next(e)
    const { lines, blocks } = parse(e.props.text)
    if (blocks.length === 0) return next(e)

    const { Box, Button } = $.ui.resolve(e)
    const copy = async (b: Block, surface: typeof e.surface) => {
      const r = await $.ui.copy({ text: b.code, surface })
      $.ui.toast(r.isCopied ? `Copied block ${b.n}` : 'Copy failed')
    }

    // The reply is drawn in pieces, each ending at a code block's closing
    // fence, so each block's button sits right under it. Every piece is the
    // engine's own drawing of that slice of text; only the first keeps the
    // reply's bullet.
    const pieces: { text: string; block?: Block }[] = []
    let from = 0
    for (const b of blocks) {
      pieces.push({ text: lines.slice(from, b.end + 1).join('\n'), block: b })
      from = b.end + 1
    }
    const rest = lines.slice(from).join('\n')
    if (rest.trim() !== '') pieces.push({ text: rest })

    const drawn: Awaited<ReturnType<typeof next>>[] = []
    for (const [k, p] of pieces.entries()) {
      const text = k === 0 ? p.text : p.text.replace(/^\n+/, '')
      drawn.push(await next({ ...e, props: { ...e.props, text, isFirstOfReply: k === 0 && e.props.isFirstOfReply } }))
    }

    return (
      <Box flexDirection="column">
        {pieces.map((p, k) => (
          <Box key={`piece-${k}`} flexDirection="column">
            {drawn[k]}
            {p.block && (
              <Box marginLeft={2}>
                <Button key={p.block.key} label={p.block.label} dimColor onPress={press => copy(p.block!, press.surface)} />
              </Box>
            )}
          </Box>
        ))}
      </Box>
    )
  })
}
