// RSA encryption key generation and primality testing
// Uses Miller-Rabin primality test and Extended Euclidean algorithm
//
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.RSA;
interface
  uses Apus.LongMath;

  var
    RSArandom:array[0..63] of byte; // external entropy source for random generation

  // Generate RSA key pair: base=modulus (p*q), pub=public exponent, pvt=private exponent
  procedure GenerateKeyPair(var base,pub,pvt:TBigInt);
  procedure GenerateKeyPair2(var base,pub,pvt:TBigInt2);

  // Miller-Rabin primality test
  function IsPrime(v:TBigInt;iterations:integer=100):boolean;
  procedure GetPrime(var v:TBigInt); // find largest prime <= v
  function IsPrime2(v:TBigInt2;iterations:integer=100):boolean;
  procedure GetPrime2(var v:TBigInt2);

  // Fill buffer with pseudo-random data
  procedure FillRand(var buf;size:integer);

implementation
  uses {$IFDEF SELF_TEST}Apus.Core,{$ENDIF}SysUtils;

  var
    randPos:integer;
    smallPrimes:array[1..2000] of integer; // precomputed small primes for trial division
    smallPrimesInitialized:boolean;

  // Lazy initialization of small primes table
  procedure InitSmallPrimes;
  var
    idx,primeCount,candidate,divisor,maxDivisor:integer;
    isPrimeCandidate:boolean;
  begin
    if smallPrimesInitialized then exit;
    // generate first 2000 prime numbers using Sieve of Eratosthenes variant
    smallPrimes[1]:=2;
    smallPrimes[2]:=3;
    primeCount:=2;
    candidate:=5;
    while primeCount<2000 do begin
      isPrimeCandidate:=true;
      maxDivisor:=round(sqrt(candidate));
      for idx:=2 to primeCount do begin
        divisor:=smallPrimes[idx];
        if divisor>maxDivisor then break;
        if candidate mod divisor=0 then begin
          isPrimeCandidate:=false;
          break;
        end;
      end;
      if isPrimeCandidate then begin
        inc(primeCount);
        smallPrimes[primeCount]:=candidate;
      end;
      inc(candidate,2); // check only odd numbers
    end;
    smallPrimesInitialized:=true;
  end;

  procedure FillRand(var buf;size:integer);
  var
    bytePtr:^Byte;
    i:integer;
    {$IFDEF DEBUG}
    checksum:integer;
    {$ENDIF}
  begin
    {$IFDEF DEBUG}
    // verify RSArandom is initialized (not all zeros)
    checksum:=0;
    for i:=0 to High(RSArandom) do
      checksum:=checksum or RSArandom[i];
    Assert(checksum<>0,'RSArandom must be initialized before use');
    {$ENDIF}
    bytePtr:=@buf;
    for i:=1 to size do begin
      bytePtr^:=random(256) xor RSArandom[randPos and 63];
      inc(bytePtr);
      inc(randPos,random(5));
    end;
  end;

  // Brute force primality test for small numbers
  function ForceTestPrime(v:int64):boolean;
  var
    divisor:integer;
    maxDivisor:integer;
    sqrtV:double;
  begin
    sqrtV:=v;
    maxDivisor:=round(sqrt(sqrtV));
    for divisor:=2 to maxDivisor do
      if v mod divisor=0 then begin
        result:=false;
        exit;
      end;
    result:=true;
  end;

  // Miller-Rabin probabilistic primality test
  // Returns true if v is probably prime with error probability < 4^(-iterations)
  function IsPrime(v:TBigInt;iterations:integer=100):boolean;
  var
    i,j,bitLength,factorShift,witnessCount,cnt,maxDivisor:integer;
    oddPart:TBigInt; // v-1 = 2^factorShift * oddPart
    witness,divisor,quotient,remainder,vMinus1:TBigInt;
    isWitness:boolean;
  begin
    InitSmallPrimes;
    bitLength:=bLastBit(v);
    if bitLength<28 then maxDivisor:=round(sqrt(v[0]))
      else maxDivisor:=1000000; // {$ELSE} bitLength>=28

    // trial division by small primes
    result:=true;
    fillchar(divisor,sizeof(divisor),0);
    for i:=2 to length(smallPrimes) do begin
      divisor[0]:=smallPrimes[i];
      if divisor[0]>maxDivisor then exit;
      bDiv(v,divisor,quotient,remainder);
      if IsZero(remainder) then begin
        result:=false;
        exit;
      end;
    end;

    // Miller-Rabin test for larger numbers
    if bitLength<=28 then exit; // trial division is sufficient for small numbers

    bitLength:=bitLength div 8; // convert to byte length

    // find factorShift where v-1 = 2^factorShift * oddPart
    for factorShift:=1 to 255 do // skip bit 0 as it's subtracted
      if v[factorShift shr 5] and (1 shl (factorShift and 31))>0 then break;

    oddPart:=v;
    bShr(oddPart,factorShift);
    witnessCount:=0;
    vMinus1:=v;
    bDec(vMinus1);

    repeat
      // generate random witness 1 < witness < v
      FillChar(witness,sizeof(witness),0);
      repeat
        FillRand(witness,bitLength);
      until witness[0]>1; // {$ELSE} witness<=1

      // check if witness proves compositeness
      bDiv(v,witness,quotient,remainder);
      if isZero(remainder) then begin // v is divisible by witness
        result:=false;
        exit;
      end;

      witness:=bPowMod(witness,oddPart,v);
      if (witness[0]=1) and (witness[1]=0) and (witness[2]=0) and (witness[3]=0) then begin
        inc(witnessCount);
        continue; // witness passed this round
      end;

      isWitness:=false;
      for j:=0 to factorShift-1 do begin
        if j>0 then begin
          bSqr(witness);
          bDiv(witness,v,quotient,remainder);
          witness:=remainder;
        end;
        if bCmp(witness,vMinus1)=0 then begin
          isWitness:=true;
          break;
        end;
      end; // {$ELSE} for j

      if not isWitness then begin
        result:=false;
        exit;
      end else // {$ELSE} not isWitness
        inc(witnessCount);
    until witnessCount>=iterations;
  end;

  // Miller-Rabin primality test for TBigInt2 (256-bit)
  function IsPrime2(v:TBigInt2;iterations:integer=100):boolean;
  var
    i,j,bitLength,factorShift,witnessCount,cnt,maxDivisor:integer;
    oddPart:TBigInt2;
    witness,divisor,quotient,remainder,vMinus1:TBigInt2;
    isWitness:boolean;
  begin
    InitSmallPrimes;
    bitLength:=bLastBit2(v);
    if bitLength<28 then maxDivisor:=round(sqrt(v[0]))
      else maxDivisor:=1000000; // {$ELSE} bitLength>=28

    // trial division by small primes
    result:=true;
    fillchar(divisor,sizeof(divisor),0);
    for i:=2 to length(smallPrimes) do begin
      divisor[0]:=smallPrimes[i];
      if divisor[0]>maxDivisor then exit;
      bDiv2(v,divisor,quotient,remainder);
      if IsZero2(remainder) then begin
        result:=false;
        exit;
      end;
    end;

    // Miller-Rabin test for larger numbers
    if bitLength<=28 then exit; // trial division is sufficient for small numbers

    bitLength:=bitLength div 8;

    // Find factorShift where v-1 = 2^factorShift * oddPart
    for factorShift:=1 to 255 do // skip bit 0 as it's subtracted
      if v[factorShift shr 5] and (1 shl (factorShift and 31))>0 then break;

    oddPart:=v;
    bShr2(oddPart,factorShift);
    witnessCount:=0;
    vMinus1:=v;
    bDec2(vMinus1);

    repeat
      // Generate random witness 1 < witness < v
      FillChar(witness,sizeof(witness),0);
      repeat
        FillRand(witness,bitLength);
      until witness[0]>1; // {$ELSE} witness<=1

      // Check if witness proves compositeness
      bDiv2(v,witness,quotient,remainder);
      if isZero2(remainder) then begin // v is divisible by witness
        result:=false;
        exit;
      end;

      witness:=bPowMod2(witness,oddPart,v);
      if (witness[0]=1) and (witness[1]=0) and (witness[2]=0) and (witness[3]=0) then begin
        inc(witnessCount);
        continue; // witness passed this round
      end;

      isWitness:=false;
      for j:=0 to factorShift-1 do begin
        if j>0 then begin
          bSqr2(witness);
          bDiv2(witness,v,quotient,remainder);
          witness:=remainder;
        end;
        if bCmp2(witness,vMinus1)=0 then begin
          isWitness:=true;
          break;
        end;
      end; // {$ELSE} for j

      if not isWitness then begin
        result:=false;
        exit;
      end else // {$ELSE} not isWitness
        inc(witnessCount);
    until witnessCount>=iterations;
  end;

  // Find largest prime number <= v by decrementing by 2
  procedure GetPrime(var v:TBigInt);
  var
    c:cardinal;
  begin
    if v[0] and 1=0 then bDec(v); // make odd
    while not isPrime(v,100) do begin
      bDec(v,2); // check only odd numbers
    end;
{   if not ForceTestPrime(int64(v[1]) shl 32+v[0]) then
      writeln('Failed!');}
  end;

  procedure GetPrime2(var v:TBigInt2);
  var
    c:cardinal;
  begin
    if v[0] and 1=0 then bDec2(v); // make odd
    while not isPrime2(v,100) do begin
      bDec2(v,2); // check only odd numbers
    end;
  end;

  // Generate RSA-512 key pair using standard algorithm
  // base = p*q (modulus), pub = public exponent, pvt = private exponent
  procedure GenerateKeyPair(var base,pub,pvt:TBigInt);
  var
    i,j:integer;
    prime1,prime2,temp1,temp2:TBigInt;
    eulerPhi:TBigInt; // φ(n) = (p-1)*(q-1)
    quotients:array[2..80] of TBigInt; // quotients from Extended Euclidean algorithm
  begin
    // generate two random large primes p and q
    fillchar(prime1,sizeof(prime1),0);
    fillchar(prime2,sizeof(prime2),0);

    FillRand(prime1,8);
    prime1[1]:=prime1[1] or $80000000; // ensure high bit set

    repeat
      FillRand(prime2,8);
      prime2[1]:=prime2[1] or $80000000;
    until (prime1[1] and $FC000000<>prime2[1] and $FC000000); // ensure p and q differ significantly

    GetPrime(prime1);
    GetPrime(prime2);

    // calculate modulus n = p*q
    base:=bMult(prime1,prime2);

    // calculate Euler's totient φ(n) = (p-1)*(q-1)
    bDec(prime1);
    bDec(prime2);
    eulerPhi:=bMult(prime1,prime2);

    // generate public exponent (must be coprime with φ(n))
    fillchar(pub,sizeof(pub),0);
    FillRand(pub,6);
    GetPrime(pub);

    // Extended Euclidean algorithm to find private exponent pvt
    // such that (pub * pvt) mod φ(n) = 1
    i:=2;
    temp1:=eulerPhi;
    temp2:=pub;
    repeat
      bDiv(temp1,temp2,quotients[i],prime1);
      temp1:=temp2;
      temp2:=prime1;
      inc(i);
    until (temp2[0]=1) and (temp2[1]=0) and (temp2[2]=0) and (temp2[3]=0); // gcd=1

    dec(i);

    // back-substitution to find modular inverse
    fillchar(prime1,sizeof(prime1),0);
    bInc(prime1); // prime1=1
    prime2:=quotients[i];
    bNeg(prime2);

    while i>2 do begin
      dec(i);
      temp1:=prime1;
      prime1:=prime2;
      prime2:=bMult(prime1,quotients[i]);
      bSub(prime2,temp1);
      bNeg(prime2);
    end;

    bAdd(prime2,eulerPhi);
    pvt:=prime2;
  end;

  // Generate RSA-1024 key pair using standard algorithm
  procedure GenerateKeyPair2(var base,pub,pvt:TBigInt2);
  var
    i,j:integer;
    prime1,prime2,temp1,temp2:TBigInt2;
    eulerPhi:TBigInt2; // φ(n) = (p-1)*(q-1)
    quotients:array[2..180] of TBigInt2;
  begin
    // generate two random large primes p and q
    fillchar(prime1,sizeof(prime1),0);
    fillchar(prime2,sizeof(prime2),0);

    FillRand(prime1,16);
    prime1[3]:=prime1[3] or $80000000; // ensure high bit set

    repeat
      FillRand(prime2,16);
      prime2[3]:=prime2[3] or $80000000;
    until (prime1[3] and $FC000000<>prime2[3] and $FC000000); // ensure p and q differ significantly

    GetPrime2(prime1);
    GetPrime2(prime2);

    // calculate modulus n = p*q
    base:=bMult2(prime1,prime2);

    // calculate Euler's totient φ(n) = (p-1)*(q-1)
    bDec2(prime1);
    bDec2(prime2);
    eulerPhi:=bMult2(prime1,prime2);

    // generate public exponent (must be coprime with φ(n))
    fillchar(pub,sizeof(pub),0);
    FillRand(pub,7);
    GetPrime2(pub);

    // Extended Euclidean algorithm to find private exponent pvt
    // such that (pub * pvt) mod φ(n) = 1
    i:=2;
    temp1:=eulerPhi;
    temp2:=pub;
    repeat
      bDiv2(temp1,temp2,quotients[i],prime1);
      temp1:=temp2;
      temp2:=prime1;
      inc(i);
    until (temp2[0]=1) and (temp2[1]=0) and (temp2[2]=0) and (temp2[3]=0) and
      (temp2[4]=0) and (temp2[5]=0) and (temp2[6]=0) and (temp2[7]=0); // gcd=1

    dec(i);

    // back-substitution to find modular inverse
    fillchar(prime1,sizeof(prime1),0);
    bInc2(prime1); // prime1=1
    prime2:=quotients[i];
    bNeg2(prime2);

    while i>2 do begin
      dec(i);
      temp1:=prime1;
      prime1:=prime2;
      prime2:=bMult2(prime1,quotients[i]);
      bSub2(prime2,temp1);
      bNeg2(prime2);
    end;

    bAdd2(prime2,eulerPhi);
    pvt:=prime2;
  end;

{$IFDEF SELF_TEST}
  // Self-test procedure to verify all module functions
  procedure SelfTest;
  var
    i:integer;
    buf1,buf2:array[0..15] of byte;
    v:TBigInt;
    v2:TBigInt2;
    base,pub,pvt:TBigInt;
    base2,pub2,pvt2:TBigInt2;
    msg,encrypted,decrypted:TBigInt;
    allZero:boolean;
    failed:boolean;
  begin
    writeln('Apus.RSA self-test started...');
    failed:=false;

    // initialize RSArandom with test data
    for i:=0 to High(RSArandom) do
      RSArandom[i]:=byte(i*17+42);

    // Test 1: FillRand generates different values
    write('Test 1: FillRand... ');
    FillRand(buf1,sizeof(buf1));
    FillRand(buf2,sizeof(buf2));
    allZero:=true;
    for i:=0 to High(buf1) do
      if buf1[i]<>buf2[i] then begin
        allZero:=false;
        break;
      end;
    if allZero then begin
      writeln('FAILED: FillRand must generate different values');
      failed:=true;
    end else // {$ELSE} not allZero
      writeln('OK');

    // Test 2: ForceTestPrime on known primes
    write('Test 2: ForceTestPrime... ');
    if not ForceTestPrime(2) then begin
      writeln('FAILED: 2 is prime');
      failed:=true;
    end else if not ForceTestPrime(3) then begin // {$ELSE} ForceTestPrime(2)
      writeln('FAILED: 3 is prime');
      failed:=true;
    end else if not ForceTestPrime(17) then begin // {$ELSE} ForceTestPrime(3)
      writeln('FAILED: 17 is prime');
      failed:=true;
    end else if not ForceTestPrime(97) then begin // {$ELSE} ForceTestPrime(17)
      writeln('FAILED: 97 is prime');
      failed:=true;
    end else if ForceTestPrime(4) then begin // {$ELSE} ForceTestPrime(97)
      writeln('FAILED: 4 is not prime');
      failed:=true;
    end else if ForceTestPrime(100) then begin // {$ELSE} ForceTestPrime(4)
      writeln('FAILED: 100 is not prime');
      failed:=true;
    end else // {$ELSE} ForceTestPrime(100)
      writeln('OK');

    // Test 3: IsPrime on small numbers
    write('Test 3: IsPrime... ');
    fillchar(v,sizeof(v),0);
    v[0]:=2;
    if not IsPrime(v,10) then begin
      writeln('FAILED: 2 is prime');
      failed:=true;
    end else begin // {$ELSE} IsPrime(2)
      v[0]:=17;
      if not IsPrime(v,10) then begin
        writeln('FAILED: 17 is prime');
        failed:=true;
      end else begin // {$ELSE} IsPrime(17)
        v[0]:=4;
        if IsPrime(v,10) then begin
          writeln('FAILED: 4 is not prime');
          failed:=true;
        end else begin // {$ELSE} IsPrime(4)
          v[0]:=100;
          if IsPrime(v,10) then begin
            writeln('FAILED: 100 is not prime');
            failed:=true;
          end else // {$ELSE} IsPrime(100)
            writeln('OK');
        end;
      end;
    end;

    // Test 4: IsPrime2 on small numbers
    write('Test 4: IsPrime2... ');
    fillchar(v2,sizeof(v2),0);
    v2[0]:=2;
    if not IsPrime2(v2,10) then begin
      writeln('FAILED: 2 is prime (TBigInt2)');
      failed:=true;
    end else begin // {$ELSE} IsPrime2(2)
      v2[0]:=97;
      if not IsPrime2(v2,10) then begin
        writeln('FAILED: 97 is prime (TBigInt2)');
        failed:=true;
      end else begin // {$ELSE} IsPrime2(97)
        v2[0]:=4;
        if IsPrime2(v2,10) then begin
          writeln('FAILED: 4 is not prime (TBigInt2)');
          failed:=true;
        end else // {$ELSE} IsPrime2(4)
          writeln('OK');
      end;
    end;

    // Test 5: GetPrime finds prime <= given value
    write('Test 5: GetPrime... ');
    fillchar(v,sizeof(v),0);
    v[0]:=100;
    GetPrime(v);
    if not IsPrime(v,20) then begin
      writeln('FAILED: GetPrime result must be prime');
      failed:=true;
    end else if v[0]>100 then begin // {$ELSE} IsPrime(v)
      writeln('FAILED: GetPrime result must be <= input');
      failed:=true;
    end else // {$ELSE} v[0]<=100
      writeln('OK');

    // Test 6: GetPrime2
    write('Test 6: GetPrime2... ');
    fillchar(v2,sizeof(v2),0);
    v2[0]:=100;
    GetPrime2(v2);
    if not IsPrime2(v2,20) then begin
      writeln('FAILED: GetPrime2 result must be prime');
      failed:=true;
    end else // {$ELSE} IsPrime2(v2)
      writeln('OK');

    // Test 7: GenerateKeyPair generates valid key pair
    write('Test 7: GenerateKeyPair... ');
    fillchar(base,sizeof(base),0);
    fillchar(pub,sizeof(pub),0);
    fillchar(pvt,sizeof(pvt),0);
    GenerateKeyPair(base,pub,pvt);
    if (base[0]=0) and (base[1]=0) then begin
      writeln('FAILED: base must not be zero');
      failed:=true;
    end else if not IsPrime(pub,20) then begin // {$ELSE} base<>0
      writeln('FAILED: public exponent must be prime');
      failed:=true;
    end else // {$ELSE} IsPrime(pub)
      writeln('OK');

    // Test 8: GenerateKeyPair2 generates valid key pair
    write('Test 8: GenerateKeyPair2... ');
    fillchar(base2,sizeof(base2),0);
    fillchar(pub2,sizeof(pub2),0);
    fillchar(pvt2,sizeof(pvt2),0);
    GenerateKeyPair2(base2,pub2,pvt2);
    if (base2[0]=0) and (base2[1]=0) then begin
      writeln('FAILED: base2 must not be zero');
      failed:=true;
    end else if not IsPrime2(pub2,20) then begin // {$ELSE} base2<>0
      writeln('FAILED: public exponent must be prime (TBigInt2)');
      failed:=true;
    end else // {$ELSE} IsPrime2(pub2)
      writeln('OK');

    // Test 9: Encryption/decryption roundtrip
    write('Test 9: RSA encrypt/decrypt... ');
    fillchar(msg,sizeof(msg),0);
    msg[0]:=$12345678;
    msg[1]:=$9ABCDEF0;
    encrypted:=bPowMod(msg,pub,base);
    decrypted:=bPowMod(encrypted,pvt,base);
    if (decrypted[0]<>msg[0]) or (decrypted[1]<>msg[1]) then begin
      writeln('FAILED: RSA encrypt/decrypt must roundtrip');
      failed:=true;
    end else // {$ELSE} decrypted=msg
      writeln('OK');

    // summary
    writeln;
    if failed then begin
      writeln('*** Apus.RSA self-test FAILED ***');
      ExitCode:=1;
    end else // {$ELSE} not failed
      writeln('=== Apus.RSA self-test PASSED ===');

    if IsDebuggerPresent then begin
      writeln;
      write('Press Enter to continue...');
      readln;
    end;
  end;
{$ENDIF}

initialization
{$IFDEF SELF_TEST}
  SelfTest;
{$ENDIF}

end.
