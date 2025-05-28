# VCL to FireMonkey form converter

<img src="Converter.png" width="614" height="582"/>

The aim of this project is to help you to convert your existing VCL forms to FireMonkey (FMX) framework, automating as much work as possible. Some changes in Pas-file are also made, but they are related only to form itself, all logic stays intact, so do not expect to have a fully working app after convertation.

Here you can see a demo converted to FMX:
<img src="BeforeAndAfter.png"/>

You should remember, that FMX framework puts all responsibility for external looks of the controls on styles, so, for example, buttons do not even have properties to select icon size or position. This should be handled by styles. Lets imagine, that your app uses four different icon sizes, these icons can be in three different positions, and button can be either normal or a speedbutton. This means that you will have to create 4 * 3 * 2 = 24 separate custom styles just for buttons. This would be a nightmare to maintain, that is why this project also provides a few custom styles in "Style Generation" folder. These styles are special because they allow you to tweak how they look. For example for buttons you can select one of four icon positions and any icon size.

To select some style, you need to enter its name into StyleLookup property of the control, like this:

    StyleLookup = 'VCL2FMXButtonStyle'
If you want icon to be on top of the text, you can add a parameter:

    StyleLookup = 'VCL2FMXButtonStyle?GlyphPosition=Top'
If you need two parameters, than you can specify them like this:

    StyleLookup = 'VCL2FMXButtonStyle?GlyphSize=64&GlyphPosition=Top'
As you probably already guessed, URL parsing code is used here, so all rules for parameters are the same.

When a control asks for that style, it will be built on the fly, according to provided parameters.

How these styles look, you ask? - Like regular VCL controls, because they use Windows Theme API. However implementation is quite simple, so it is possible to find differences. Also amount of supported controls is rather small at the moment. Below is a full list of styles with details about supported parameters.

## Styles and their parameters

### VCL2FMXButtonStyle

A style for simple TButton control, supports two parameters:
| Parameter | Possible values | Description |
|--|--|--|
| GlyphPosition | top, right, bottom, left | Position of the icon glyph relative to the text caption. Default value is left |
| GlyphSize | any integer or fractional number | Width and height of the glyph. Default value is 16 |

### VCL2FMXCheckBoxStyle

A style for TCheckBox control, supports one parameter:
| Parameter | Possible values | Description |
|--|--|--|
| BackgroundColor| any color definition, supported by System.UIConsts.StringToAlphaColor | Color of control background. By default background is transparent |

### VCL2FMXEditStyle

A style for TEdit control, supports one parameter:
| Parameter | Possible values | Description |
|--|--|--|
| BackgroundColor| any color definition, supported by System.UIConsts.StringToAlphaColor | Color of control background, behind text. By default background is drawn according to the windows theme |

### VCL2FMXGroupBoxStyle

A style for TGroupBox control, supports two parameters:
| Parameter | Possible values | Description |
|--|--|--|
| BackgroundColor | any color definition, supported by System.UIConsts.StringToAlphaColor | Color of control background. By default background is transparent |
| ShowFrame | boolean value supported by System.SysUtils.StrToBoolDef | Whether to show frame or not. Default value is true |

### VCL2FMXLabelStyle

A style for TLabel control, supports one parameter:
| Parameter | Possible values | Description |
|--|--|--|
| BackgroundColor| any color definition, supported by System.UIConsts.StringToAlphaColor | Color of control background. By default background is transparent |

### VCL2FMXMemoStyle

A style for TMemo control, supports one parameter:
| Parameter | Possible values | Description |
|--|--|--|
| BackgroundColor| any color definition, supported by System.UIConsts.StringToAlphaColor | Color of control background, behind text. By default background is drawn according to the windows theme |

### VCL2FMXPanelStyle

A style for TPanel control, supports one parameter:
| Parameter | Possible values | Description |
|--|--|--|
| BackgroundColor| any color definition, supported by System.UIConsts.StringToAlphaColor | Color of control background. Default color is $FFF0F0F0 |

### VCL2FMXRadioButtonStyle

A style for TRadioButton control, supports one parameter:
| Parameter | Possible values | Description |
|--|--|--|
| BackgroundColor| any color definition, supported by System.UIConsts.StringToAlphaColor | Color of control background. By default background is transparent |

### VCL2FMXScrollBoxStyle

A style for TScrollBox control, supports one parameter:
| Parameter | Possible values | Description |
|--|--|--|
| BackgroundColor | any color definition, supported by System.UIConsts.StringToAlphaColor | Color of control background. By default background is transparent |

### VCL2FMXSpeedButtonStyle

A style for TSpeedButton control, supports two parameters:
| Parameter | Possible values | Description |
|--|--|--|
| GlyphPosition | top, right, bottom, left | Position of the icon glyph relative to the text caption. Default value is left |
| GlyphSize | any integer or fractional number | Width and height of the glyph. Default value is 16 |

## Class helpers for styles

All styles above have corresponding class helpers, that allow you to keep some of the old code without rewriting. For example you had such code:

    Edit1.Color := clRed;
TEdit in FMX does not have Color property, but thanks to class helper, you can keep this code:

    Edit1.Color := claRed;
The only thing that you need to change here is a switch from regular color to alphacolor, clRed -> claRed. Maybe in future converter will be able to do such replacements automatically.

Under the hood these class helpers read and write StyleLookup property of the control, adding style parameters when necessary.

## Convertation rules
Default behaviour of the converter is to simply copy property from VCL control to FMX control without any changes. When this is not enough, you can add convertation rules for properties.
TCheckBox in VCL has property called Checked, in FMX this property is called IsChecked. Rule for this property looks like this:

    Checked=IsChecked
To the left property name in VCL, and to the right - in FMX.

> Converter keeps list of all properties that have to be renamed, even
> if certain rule was  not used during convertation. When converter has
> created fmx file, it will try to find and rename all known properties
> in pas file. This is actually the most time consuming part of the
> convertation.

Often properties in VCL do not have any replacements in FMX and have to be deleted. It can be done with a following rule:

    AllowGrayed=#Delete#
TCheckBox in FMX does not support gray state of the check mark, so we have to delete AllowGrayed property. Text between two "#" symbols is an action. Each action invokes some special code inside converter. Delete action will simply delete current property.
Actions can have parameters. Everything after second "#" is a parameter. Lets look at following rule:

    Align=#ItemEnum#TAlign
Action ItemEnum works with enum properties. It loads rules from TAlign section of the file and uses them to convert each individual element of the enum.
Most rules can combine all of the above elements and follow this anatomy:

    VCLPropName=FMXPropName#Action#Parameter
Parameters without actions are not allowed.
For example TEdit in VCL has PasswordChar property that allows to chose which symbol will be used to hide text of the password, but in FMX TEdit only has boolean Password property. So this is the rule for this property:

    PasswordChar=Password#SetValue#True
SetValue action will unconditionally set value of the property. It does not know anything about property types, so its parameter should be exactly the way this value is stored in fmx file.

But what if current Edit does not use PasswordChar, how to set Password to False? This is where you should consider default values of the properties and the fact that property with default value will be omitted from dfm or fmx file. If PasswordChar was not set and has default value, than this property will be absent from dfm file. Because of this, rule above will not be executed and Password property will not be added to fmx file. And default value for Password property is False.
#### Wildcards
The last important thing to know about general properties of the rules is that they support wildcards. You can replace a single symbol with "?" sign or multiple symbols with a "*" sign. Other common constructs for wildcards are not supported. This is done to simplify matching wildcards between VCL and FMX property names. Lets look at one of the rules for TChart:

    *.Font.Name=*.Font.Family
This rule will convert property name "Legend.Title.Font.Name" to "Legend.Title.Font.Family" and "BottomAxis.LabelsFormat.Font.Name" to "BottomAxis.LabelsFormat.Font.Family".
Algorythm can even match multiple wildcards in a single rule, but count of wildcards on both sides of "=" sign should be the same.

### Sections
File with convertation rules uses INI-file format. TMemIniFile class is used to parse it. INI-files are split in to multiple sections. Most sections have a name of some FMX control class, for example TButton or TEdit.
Sometimes, however, VCL and FMX class names do not match. To fix this issue there is a special section called "ObjectChanges". It contains class renaming rules. For example rule for TSpinEdit:

    TSpinEdit=TSpinBox
According to this rule TSpinEdit in VCL form will be replaced by TSpinBox in FMX form. Rules from TSpinBox section will be used to convert properties.

It is possible to convert multiple VCL classes to a single FMX class. For example both TDBEdit and TMaskEdit are converted to TEdit. Of course, rules for all TEdit related classes should not have any conflicts, because, so far, converter does not have any means to resolve such conflicts.
#### Common properties
Controls in VCL and FMX inherit a lot of their properties from their common ancestors. That is why, a lot of the same properties can be found in a lot of different controls. It would be a burden to create duplicate rules for all controls and then synchronize changes between all of them. That is why, there is another special section called "CommonProperties". This section contains rules that will be used for each class found by converter. Even if this class does not have separate section with rules, common rules will still be applied to it.

Class specific rules replace common rules when conflicts are found. Wildcards are also considered when calculating rule conflicts. For example "CommonProperties" section contains a lot of rules for handling fonts:

    Font.Charset=#Delete#
    Font.Color=TextSettings.FontColor#Color#
    Font.Height=TextSettings.Font.Size#FontSize#
    Font.Name=TextSettings.Font.Family
    Font.Orientation=#Delete#
    Font.Pitch=#Delete#
But rules section for TComboBox has this rule:

    Font.*=#Delete#
That is why all rules from "CommonProperties" section mentioned above will be discarded and all Font-related properties will be removed for TComboBox.
#### Forms and Frames
Handling of forms and frames has a lot of differences from other classes.
First of all, their class name can be anything except TForm or TFrame. That is why root class of the dfm file is the one that will use TForm section, even if it is some descendant of TFrame. Converter does not have any means to distinguish between forms and frames.
Second difference is that "CommonProperties" section is not used. As it turnouts, rules for forms have too many differences from other controls, so there is simply no benefit from using "CommonProperties" section.
#### Companion sections
Default anatomy of rules can't handle a lot of common problems, that is why sections for rules of different types have been introduced.
The simplest example is Include companion section. For example here is Include section for TBindSourceDB:

    [TBindSourceDB#Include]
    Data.Bind.Components=inc
    Data.Bind.DBScope=inc
    Data.Bind.EngExt=inc
    Data.Bind.Grid=inc
    Fmx.Bind.DBEngExt=inc
    Fmx.Bind.Editors=inc
    Fmx.Bind.Grid=inc
    System.Bindings.Outputs=inc
The idea of this section is that controls in VCL and FMX can be defined in units with very different names, and need some additional units to function properly. Include section contains a list of all required units for current class, defined before "#" sign. Since each line of the section has to follow INI file format, each line ends with "=inc". This ending does not have any meaning and is ignored by converter.

TForm class is the only one that has similar companion section called "TForm#Replace". The purpose of it is to maintain uses section of pas file. If some VCL unit can be replaced by FMX unit, rule like this is used:

    Vcl.ActnList=FMX.ActnList
If VCL unit does not have FMX counterparts, than it is simply removed from the list:

    Vcl.ActnMan=

> You have probably noticed that full names of the units are used. If
> your code uses short unit names, than you will have to fix them before
> convertation. You can use MMX Code Explorer to do that. It has very
> handy function called "Format Uses Clause".

Sometimes, when some property is set, another companion property has to be set. This is done in AddIfPresent companion section. Here is an example:

    Size.Height=Size.PlatformDefault=False
If Size.Height property is defined, than we can't use default sizes and Size.PlatformDefault property has to be set to False. The line after first "=" sign is written to FMX file as is, without any additional processing except light formatting.
So far AddIfPresent is the only supported companion for "CommonProperties" section. Conflicts between "CommonProperties#AddIfPresent" section and AddIfPresent section, specific for a class, are handled in the same way as described in "Common properties" chapter above.
#### Additional way to handle default values of the properties
As discussed above, if some property has a default value, it will not be written to dfm file, and hence no rule will be executed for this property. But sometimes there is a need to do exactly that. For this reason "DefaultValueProperty" companion section has been introduced. Great example of its usage is TMemo control. In VCL it has property ScrollBars whose default value is ssNone. But in FMX TMemo has property ShowScrollBars with a default value of True. This is how these properties are handled:

    [TMemo]
    ScrollBars=#Delete#
    [TMemo#DefaultValueProperty]
    ScrollBars=ShowScrollBars=False
If ScrollBars is set to anything except ssNone, than we delete this property, so that ShowScrollBars can assume its default value. But if we have not found ScrollBars property among properties of current memo, than it was set to ssNone and we need to add ShowScrollBars=False to the list of properties.

Another big problem that can cause a lot of problems during convertation is usage of parent fonts. FMX does not have mechanics like this at all. That is why convertor has to calculate correct fonts for each control during convertation. This is done with a following rules:

    [CommonProperties]
    ParentFont=#Delete#
    [TMemo#DefaultValueProperty]
    ParentFont=#CopyFromParent#Font.*
Default value of ParentFont property is True. If it was set to False, then Font related properties have been set, and we can simply delete ParentFont. If ParentFont was not found among properties of current memo, than it was set to True and we need to copy Font properties from parent control. CopyFromParent action has a few unsupported edge cases, but most of the time gets the job done.

### Generation of new controls
Some controls in VCL can store their images themself. For example TSpeedButton can store its image in Glyph property. In FMX TSpeedButton has to rely on TImageList for icon storage. That is why during convertation new TImageList called SingletoneImageList can be created by converter. All such images will be stored in this image list. This is done by following rule:

    Glyph.Data=#GenerateControl#ImageItem
GenerateControl action has a lot of possible parameters. One of them is related to the fact that VCL has DB-aware controls, but FMX does not. It uses LiveBindings to bind controls to DB fields. When converter stumbles upon DB-aware control, it has to convert it to simple control and generate live binding for it. Algorithm is similar to icons. New TBindingsList called SingletoneBindingsList is created and new bindings are added for each control. Here are rules for this:

    DataField=#GenerateControl#FieldLink
    DataSource=#GenerateControl#FieldLink
First rule will create new binding, and second one will add information about DataSource to it.

Sometimes a single FMX control is not enough to replace VCL counterpart. Good example is TRadioGroup. FMX does not have anything similar, but you can use TGroupBox with a number of TRadioButton-s on it. Converter can handle this by replacing TRadioGroup class with TGroupBox and using two rules:

    ItemIndex=#GenerateControl#SelectRadioButton
    Items.Strings=#GenerateControl#MultipleRadioButtons
Second rule will generate a necessary amount of radio buttons and will set their properties. First rule will add "IsChecked=True" to one of them.

> By default radio button names will be set to something like
> "RadioGroup1_RadioButton1". It is recommended to rename them according
> to their function. This will greatly improve readability of your code.
