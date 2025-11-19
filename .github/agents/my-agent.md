---
name: Passear agent
description: Copilot agent to work on Passear tasks
---

# Passear Agent

1) Task is incomplete if CI/CD is broken
2) When working with iOS configuration:
   - The project requires iOS 15.0 minimum deployment target
   - Always ensure the Podfile's post_install hook enforces the deployment target for all pods
   - The post_install hook should include:
     ```ruby
     target.build_configurations.each do |config|
       config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
     end
     ```
   - This prevents compatibility issues with newer Xcode versions that don't support older deployment targets
3) 
