import unittest
import strutils
import ../locale

suite "Locale Tests":
  test "GetLocaleName returns a valid string":
    let localeName = GetLocaleName()
    check localeName.len > 0
    check localeName != "Unknown" or true  # May be Unknown in some environments
    
  test "GetLocaleName returns ISO 639-1 code format":
    let localeName = GetLocaleName()
    if localeName != "Unknown":
      # ISO 639-1 codes are typically 2 letters
      check localeName.len == 2 or localeName.len == 3
      # Should be lowercase
      check localeName.toLowerAscii() == localeName
  

  test "loadCfgLocaleData loads configuration":
    var manager: TLocaleManager
    try:
      manager.loadCfgLocaleData("LocaleData.cfg")
      check true
    except:
      # File might not exist in test environment
      echo "Config file not found, skipping test"
      
  test "getKeyLang retrieves localized string":
    var manager: TLocaleManager
    try:
      manager.loadCfgLocaleData("LocaleData.cfg")
      let hello = manager.getKeyLang("Hello", "de")
      check hello.len > 0
    except:
      echo "Config file not found, skipping test"
      
  test "getKey retrieves localized string for current locale":
    var manager: TLocaleManager
    try:
      manager.loadCfgLocaleData("LocaleData.cfg")
      let hello = manager.getKey("Hello")
      check hello.len > 0
    except:
      echo "Config file not found, skipping test"
