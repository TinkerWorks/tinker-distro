diff --git a/recipes-core/rauc/files/rauc-mark-good.service b/recipes-core/rauc/files/rauc-mark-good.service
index 84986f9..d972c71 100644
--- a/recipes-core/rauc/files/rauc-mark-good.service
+++ b/recipes-core/rauc/files/rauc-mark-good.service
@@ -2,8 +2,8 @@
 Description=RAUC Good-marking Service
 ConditionKernelCommandLine=|bootchooser.active
 ConditionKernelCommandLine=|rauc.slot
-After=boot-complete.target
-Requires=boot-complete.target
+After=network-online.target boot-complete.target
+Requires=network-online.target boot-complete.target
 
 [Service]
 Type=oneshot
