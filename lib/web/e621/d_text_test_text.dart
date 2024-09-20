// #region Test Text
const testText = """
[#startAnchor]
[[#startAnchor]]
[[#endAnchor|End]]
[[#namedLinks|Named Links]]
[section=Headers]
h1.h1
h2. h2
h3.h3
h4. h4
h5.h5
h6. h6
[/section]
[section=Colors]
[color=pink]I'm pink![/color]
[color=#ff0000]I'm red![/color]
[color=#f00]I'm red too![/color]
[color=artist]I'm an artist![/color]
[color=green]I span
2 lines![/color]
[/section]
patreon.com/MariArt
MariArt.info
[i]Italics [b]and bolded [color=red]and red[/color][/b] text[/i]
[sup]Superscript[/sup][sub]Subscript[/sub][spoiler]Spoiler[/spoiler]
[quote]Quote[/quote]
[code]std::cout << "Code Block!";[/code]
`std::cout << "Code Inline!";`
[section=Lists & Tables]
* Item 1
* Item 2
** Item 2A
** Item 2B
* Item 3
[table]
  [thead]
    [tr]
      [th] header [/th]
      [th] header [/th]
      [th] header [/th]
    [/tr]
  [/thead]
  [tbody]
    [tr]
      [td] column [/td]
      [td] column [/td]
      [td] column [/td]
    [/tr]
    [tr]
      [td] column [/td]
      [td] column [/td]
      [td] column [/td]
    [/tr]
  [/tbody]
[/table]
[/section]
[section=Links]
Tag search
{{jun_kobayashi rating:s}}
Post Link
post #3796501
Post changes
post changes #3796501
Forum Topic
topic #1234
Comment
comment #12345
Blip
blip #1234
Pool
pool #1234
Set
set #1
takedown request
takedown #1
feedback record
record #14
ticket
ticket #1234
thumb
thumb #3796501
[[American Dragon: Jake Long|Named Wiki Link]] [[American Dragon: Jake Long]]
[[#startAnchor]]
[[#endAnchor|End]]
[[malka_(the_lion_king)]]
[#namedLinks]
Thank you "@/BaskyCase":https://x.com/BaskyCase & "@/nyaruh1":https://x.com/nyaruh1 for "Tennis Ace":https://wotbasket.itch.io/tennis-ace
"Twitter":https://x.com/tennisace_vn
On "Patreon":https://www.patreon.com/tennisace
whole
https://www.patreon.com/tennisace
w/o www.
https://patreon.com/tennisace
w/o scheme
www.patreon.com/tennisace
w/o scheme & www.
patreon.com/tennisace
false positive
he...well...while
escaped
<https://wotbasket.itch.io/tennis-ace>
back to back https://x.com/tennisace_vn w/ text in between https://x.com/tennisace_vn that could https://x.com/tennisace_vn confuse the parser
[/section]
[section]Pretend this is a really large block of text.[/section]
[section=Titled]This one has a title.[/section]
[section,expanded=Titled And Expanded]This is expanded and titled.[/section]
[section,expanded]This is expanded by default.[/section]
[[#startAnchor]]
[[#endAnchor|End]]
[#endAnchor]""";
// #endregion Test Text
