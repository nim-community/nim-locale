#
#
#            Nimrod's Runtime Library
#        (c) Copyright 2011 Alex Mitchell (Amrykid)
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## :Author: Alex Mitchell
##
## Implements a simple way to load strings based on the user's locale name.
##
## .. code-block:: Nimrod
##    initLocale(LocaleManager, "LocaleData.cfg") #Loads a config file with the localized strings.
##    echo(LocaleManager.getKey("Hello")) #Prints the localized string for the user's locale.
##    echo(LocaleManager.getKeyLang("Hello","de")) #Prints the localized string in the specified locale.
##    echo(<$>"Hello")
##
##
## Example CFG file:
##
## .. code-block::
##    SectionLang = en
##    [Hello] ;SectionLang makes Section headers into keys that are in that language.
##    es = "Hola"
##    de = "Hallo"


import strutils, xmlparser, tables, xmltree, os, parsecfg, streams
 
 
# FUNCTIONS RELATED TO GETTING LOCALE NAME    
when defined(windows):
  from windows import GetUserDefaultLCID, GetLocaleInfoA, LCID, LOCALE_SISO639LANGNAME

  proc GetWinLocaleName(): string =
    var locale = GetUserDefaultLCID()
    var localeName :array[0..265, char]
    var localeNameSize = GetLocaleInfoA(locale, LOCALE_SISO639LANGNAME, localeName, 256)
    return $localeName
        

elif defined(macosx):
  import parseutils
  {.passL: "-framework CoreFoundation".}
  
  type
    CFArrayRef = pointer
    CFStringRef = pointer
    CFIndex = int
  
  proc CFLocaleCopyPreferredLanguages(): CFArrayRef {.header: "<CoreFoundation/CFLocale.h>", importc.}
  proc CFArrayGetCount(theArray: CFArrayRef): CFIndex {.header: "<CoreFoundation/CFArray.h>", importc.}
  proc CFArrayGetValueAtIndex(theArray: CFArrayRef, idx: CFIndex): CFStringRef {.header: "<CoreFoundation/CFArray.h>", importc.}
  proc CFStringGetCString(theString: CFStringRef, buffer: cstring, bufferSize: CFIndex, encoding: int32): bool {.header: "<CoreFoundation/CFString.h>", importc.}
  proc CFRelease(cf: CFArrayRef) {.header: "<CoreFoundation/CFBase.h>", importc.}
  
  const kCFStringEncodingUTF8 = 0x08000100

  proc GetMacLocaleName(): string =
    var languages = CFLocaleCopyPreferredLanguages()
    if languages != nil:
      var count = CFArrayGetCount(languages)
      if count > 0:
        var langRef = CFArrayGetValueAtIndex(languages, 0)
        var langStr = cast[CFStringRef](langRef)
        var buffer: array[0..255, char]
        var success = CFStringGetCString(langStr, cast[cstring](buffer[0].addr), 256, kCFStringEncodingUTF8)
        if success:
          result = $(cast[cstring](buffer[0].addr))
          # Extract just the language code (e.g., "en" from "en-US")
          var langCode: string
          discard parseutils.parseUntil(result, langCode, '-')
          if langCode.len() > 0:
            result = langCode
        else:
          result = "Unknown"
      else:
        result = "Unknown"
      CFRelease(languages)
    else:
      result = "Unknown"
else:
  import parseutils
  
  const
    LC_CTYPE = 0
    LC_ALL = 6
  
  proc setlocale(category: cint, locale: cstring): cstring {.header: "<locale.h>", importc.}
  
  proc GetUnixLocaleName(): string =
    var locale = setlocale(LC_CTYPE, nil)
    if locale != nil and locale[0] != '\0':
      result = $locale
      # Extract language code from locale string (e.g., "en_US.UTF-8" -> "en")
      var langCode: string
      discard parseutils.parseUntil(result, langCode, '_')
      if langCode.len() > 0:
        result = langCode

    else:
      result = "Unknown"

type
  TLocaleManager* = object #An object used for localization via xml/cfg.
      table: Table[string, Table[string,string]]
      sectionLang: string
            
proc GetLocaleName*(): string =
  ## Retrieves the user's locale/language as an ISO 639-1 code string.
  when defined(windows):
      return GetWinLocaleName()
  elif defined(macosx):
      return GetMacLocaleName()
  else:
      return GetUnixLocaleName()

proc loadXmlLocaleData*(locale: var TLocaleManager, filename: string) =
  ## Initializes a TLocaleManager by loading it with localized strings from a XML file.
  
  locale.table = initTable[string, Table[string, string]]()
  var localeNode = loadXml(filename)
  for n in localeNode.items:
    if n.tag == "string":
      var key = n.attr("key")
      var innertable: Table[string, string] = initTable[string, string]()
      for trans in n.items:
        if trans.tag == "trans":
          var lang = trans.attr("lang")
          var value = trans.attr("value") #using an attribute because PXmlNode.Text is broken.
          innertable.add(lang, value)
          
      locale.table.add(key, innertable)

proc loadCfgLocaleData*(locale: var TLocaleManager, filename: string) =
  ## Initializes a TLocaleManager by loading it with localized strings from a CFG file.
  locale.table = initTable[string, Table[string, string]]()
  
  var f = newFileStream(filename, fmRead)
  if f != nil:
    var p: CfgParser
    open(p, f, filename)

    var key: string
    var innertable: Table[string, string] = initTable[string, string]()
    while true:
      var e = next(p)

      case e.kind
      of cfgEof: 
        #echo("EOF!")
        break
      of cfgSectionStart:   ## a ``[section]`` has been parsed
        #echo("new section: " & e.section)
        if innertable.len() > 0:
            locale.table.add(key, innertable)

        key = e.section
        innertable = initTable[string, string]()
      of cfgKeyValuePair:
        if key.len() == 0 and e.key == "SectionLang":
          locale.sectionLang = e.value
          #echo("Section Language: " & e.value)
        else:
          #echo("key-value-pair: " & e.key & ": " & e.value)
          innertable.add(e.key, e.value)
      of cfgError:
        echo(e.msg)
      else:
        continue

    if not locale.table.hasKey(key):
        locale.table.add(key, innertable)
        
    close(p)
  else:
    raise newException(IOError, "Invalid .cfg")


    
proc getKeyLang*(locale: var TLocaleManager, key: string, lang: string): string =
  ## Gets the localized string in the specified locale.

  if lang == locale.sectionLang:
    return key
  
  return locale.table[key][lang]
    
proc getKey*(locale: var TLocaleManager, key: string): string =
  ## Gets the localized string for the user's locale.
  return getKeyLang(locale,key, GetLocaleName())

template `<$>`(str: string): string = LocaleManager.getKey(str)
 
var
   LocaleManager: TLocaleManager
   
 
 
    
# DEBUGING TEST    
when isMainModule:
    echo(GetLocaleName()) #Prints English
    loadCfgLocaleData(LocaleManager, "LocaleData.cfg")
    echo(LocaleManager.getKey("Hello"))
    echo(LocaleManager.getKeyLang("Hello","de"))
    echo(<$>("Hello"))
