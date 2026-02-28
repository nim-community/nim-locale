import unittest
import strutils
import ../locale

suite "Locale Tests":
  test "GetLocaleName returns a valid string":
    let localeName = GetLocaleName()
    check localeName.len > 0
    check localeName != "Unknown"
    
  test "GetLocaleName returns ISO 639-1 code format":
    let localeName = GetLocaleName()
    # ISO 639-1 codes are typically 2 letters
    check localeName.len == 2 or localeName.len == 3
    # Should be lowercase
    check localeName.toLowerAscii() == localeName
  

      
  test "getKeyLang retrieves localized string":
    var manager: TLocaleManager
    manager.loadCfgLocaleData("LocaleData.cfg")
    let hello = manager.getKeyLang("Hello", "de")
    check hello.len > 0
      
  test "getKey retrieves localized string for current locale":
    var manager: TLocaleManager
    manager.loadCfgLocaleData("LocaleData.cfg")
    let hello = manager.getKey("Hello")
    check hello.len > 0
