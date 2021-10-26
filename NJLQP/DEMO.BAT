echo off
cls
echo.
echo   This is the NJLQP DEMO!
echo.
echo  This program will print two text samples; one will be printed as usual,
echo and the other will be printed with NJLQP's near-letter-quality print
echo mode.  Be sure that your printer is ready.  If you don't want to do the
echo demo, press "CTRL+C", and answer "Y" to the question.  Otherwise,
pause
copy demo1.txt prn:
njlqp demo2.txt -f
