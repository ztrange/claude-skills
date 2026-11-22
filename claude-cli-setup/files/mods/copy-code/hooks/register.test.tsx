import { expect, test } from 'claude-code/testing'

const reply = 'Intro\n\n```sh\necho one\n  echo indented\n```\n\nMiddle\n\n```python\nprint("two")\n```\n\nOutro'

test('each code block gets its own copy button, copying it verbatim', async ($, on) => {
  const copied: string[] = []
  on('ui.copy', (_, e) => { copied.push(e.text); return { value: { isCopied: true } } })

  const ui = await $.ui.mount({
    plugin: 'copy-code', surface: 'terminal', component: 'AssistantMessage',
    props: { text: reply, isFirstOfReply: true },
  })
  const buttons = await ui.findAll({ type: 'Button' })
  expect(buttons.length).toBe(2)
  for (const b of buttons) await ui.press({ key: String(b.props.key) })
  expect(copied).toEqual(['echo one\n  echo indented', 'print("two")'])
  await ui.unmount()
})

test('a reply with no code block gets no button', async $ => {
  const ui = await $.ui.mount({
    plugin: 'copy-code', surface: 'terminal', component: 'AssistantMessage',
    props: { text: 'just prose', isFirstOfReply: true },
  })
  expect(await ui.find({ type: 'Button' })).toBeUndefined()
  await ui.unmount()
})
