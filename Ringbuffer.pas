{*****************************************************************************
  The CircularBuffer team (see file NOTICE.txt) licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License. A copy of this licence is found in the root directory of
  this project in the file LICENCE.txt or alternatively at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.
*****************************************************************************}
unit Ringbuffer;

interface

uses
  SysUtils;

type
  /// <summary>
  ///   raised when there are more data written to the buffer than it can hold
  /// </summary>
  EBufferFullException  = class(Exception);
  /// <summary>
  ///   raised when a single element is taken from an empty buffer
  /// </summary>
  EBufferEmptyException = class(Exception);

  /// <summary>
  ///   types of ring buffer events: <br />
  /// </summary>
  TRingbufferEventType = (
    /// <summary>
    ///   at least one element was added
    /// </summary>
    evAdd,
    /// <summary>
    ///   at least one element was removed or deleted or the buffer is cleared
    /// </summary>
    evRemove);

  /// <summary>
  ///   Event type triggered by all operations manipulating the number of elements in the ring buffer: Add, Remove,
  ///   Delete...
  /// </summary>
  /// <param name="Count">
  ///   new number of elements in the buffer
  /// </param>
  /// <param name="Event">
  ///   type of event:
  ///   <list type="bullet">
  ///     <item>
  ///       evAdd when Count was increased,
  ///     </item>
  ///     <item>
  ///       evRemove when Count was decreased
  ///     </item>
  ///   </list>
  /// </param>
  TRingbufferNotify = procedure(Count: UInt32; Event:TRingbufferEventType) of Object;

  /// <summary>
  ///   Implementation of a generic ring buffer for all types without taking any ownership. For a ring buffer freeing
  ///   all contained objects on Destroy use <c>TObjectRingBuffer&lt;T&gt;</c>.
  /// </summary>
  /// <seealso cref="TObjectRingBuffer&lt;T&gt;">
  ///   TObjectRingBuffer&lt;T&gt;
  /// </seealso>
  TRingbuffer<T> = class(TObject)
  type
    /// <summary>
    ///   return and parameter type for most of the operators
    /// </summary>
    TRingbufferArray = TArray<T>; //array of T;
  strict protected
    /// <summary>
    ///   Static storage for all elements. The size is determined in the constructor.
    /// </summary>
    FItems        : TRingbufferArray;
    /// <summary>
    ///   Index of the first buffer item
    /// </summary>
    FStart        : UInt32;
    /// <summary>
    ///   Index of the next free buffer item, where an element can be written directly
    /// </summary>
    /// <remarks>
    ///   If <c>FNextFree = FStart</c> the buffer is either empty or full. The actual state is determined by <c>
    ///   FContainsData</c>: True means <i>the buffer is full</i>.
    /// </remarks>
    FNextFree     : UInt32;
    /// <summary>
    ///   Indicates whether the buffer actually contains data.
    /// </summary>
    /// <remarks>
    ///   If <c>FStart = FNextFree</c> the buffer is either empty or full. This field gives the missing information.
    /// </remarks>
    FContainsData : Boolean;
    /// <summary>
    ///   This event is triggered by all operations manipulating the number of elements in the ring buffer: Add,
    ///   Remove, Delete... <br />
    /// </summary>
    FNotify       : TRingbufferNotify;

    /// <summary>
    ///   Returns the number of items currently in the ring buffer
    /// </summary>
    function GetCount: UInt32;
    /// <summary>
    ///   Returns the number of elements that can be stored in the ring buffer
    /// </summary>
    function GetSize: UInt32;
    /// <summary>
    ///   Increments the Tail marker, wrapping it to 0 when necessary
    /// </summary>
    /// <param name="Increment">
    ///   How much items the Tail should be advanced
    /// </param>
    /// <remarks>
    ///   The method assumes that the case <c>Tail+ Increment &gt; First</c> is already taken care of by the caller
    /// </remarks>
{ TODO : Am Ende inline-Direktive aktivieren! }
    procedure AdvanceNextFree(Increment: UInt32); // inline;
    /// <summary>
    ///   Prototype method for freeing objects
    /// </summary>
    /// <param name="StartIndex">
    ///   Index of the first item to be deleted. Must be less than <c>EndIndex</c> and in the range <c>0 .. Count - 1</c>
    ///   . Thus wrapped buffer content cannot be deleted in one go.
    /// </param>
    /// <param name="EndIndex">
    ///   Index of the last item to be deleted. Must be larger than <c>StartIndex</c> and in the range <c>0 .. Count -
    ///   1.</c>
    /// </param>
    /// <remarks>
    ///   The current implementation is empty, but is overridden in <c>TObjectRiungBuffer&lt;T&gt;</c>.
    /// </remarks>
    procedure FreeOrNilItems(StartIndex, EndIndex: UInt32); virtual;
  public
    /// <summary>
    ///   Creates the ring buffer with the given size
    /// </summary>
    /// <param name="Size">
    ///   Number of elements the ring buffer will hold
    /// </param>
    constructor Create(Size: UInt32); overload;
    /// <summary>
    ///   Frees the ring buffer memory
    /// </summary>
    /// <example>
    ///   Any object instances in the ring buffer will not be freed. If the ring buffer shall be responsible for
    ///   managing the lifetime of those objects <c>TObjectRingbuffer&lt;T&gt;</c> would be the better choice!
    /// </example>
    destructor  Destroy; override;

    /// <summary>
    ///   Appends the given item to the ring buffer
    /// </summary>
    /// <param name="Item">
    ///   Anzuh�ngendes Element
    /// </param>
    /// <exception cref="EBufferFullException">
    ///   not enough capacity
    /// </exception>
    /// <remarks>
    ///   If there is not enough capacity an <c>EBufferFullException</c> is raised. <br />
    /// </remarks>
    procedure   Add(Item: T); overload; virtual;
    /// <summary>
    ///   Appends multiple items to the ring buffer
    /// </summary>
    /// <param name="Items">
    ///   array of elements to append
    /// </param>
    /// <exception cref="EBufferFullException">
    ///   not enough capacity
    /// </exception>
    /// <remarks>
    ///   The size of the array must be less than the free capacity of the buffer. Otherwise an <c>EBufferFullException</c>
    ///    is raised.
    /// </remarks>
    procedure   Add(Items:TRingbufferArray); overload; virtual;

    /// <summary>
    ///   Returns the first element from the ring buffer and removes it
    /// </summary>
    /// <returns>
    ///   Das Element aus dem Puffer welches am l�ngsten im Puffer ist
    /// </returns>
    /// <exception cref="EBufferEmptyException">
    ///   buffer is empty
    /// </exception>
    /// <remarks>
    ///   If the buffer is empty an <c>EBufferEmptyException</c> is raised
    /// </remarks>
    function    Remove:T; overload; virtual;
    /// <summary>
    ///   Returns the first <c>RemoveCount</c> elements from the buffer
    /// </summary>
    /// <param name="RemoveCount">
    ///   Number of elements to retrieve
    /// </param>
    /// <returns>
    ///   Array mit einer maximalen L�nge von Count
    /// </returns>
    /// <exception cref="EBufferEmptyException">
    ///   buffer is empty
    /// </exception>
    /// <exception cref="EArgumentOutOfRangeException">
    ///   <c>RemoveCount</c> exceeds buffer size
    /// </exception>
    /// <remarks>
    ///   <list type="bullet">
    ///     <item>
    ///       If there are less elements in the buffer as requested, only the vailable elements are returned
    ///     </item>
    ///     <item>
    ///       If the buffer is empty an EBufferEmptyException is raised.
    ///     </item>
    ///     <item>
    ///       If more elements are requested than the capacity of the buffer an EArgumentOutOfRangeException is
    ///       raised
    ///     </item>
    ///   </list>
    /// </remarks>
    function    Remove(RemoveCount: UInt32):TRingbufferArray; overload; virtual;
    /// <summary>
    ///   Removes the given number of elements from the buffers Head
    /// </summary>
    /// <param name="Count">
    ///   Number of elements to be deleted
    /// </param>
    /// <exception cref="EArgumentOutOfRangeException">
    ///   <c>Count</c> exceeds buffer size
    /// </exception>
    /// <remarks>
    ///   <para>
    ///     Elements are not overridden, but cannot be accessed after being deleted.
    ///   </para>
    ///   <para>
    ///     If more elements are to be deleted than are available in the buffer, the buffer is cleared.
    ///   </para>
    ///   <para>
    ///     If more elements are to be deleted than the capacity of the buffer an <b>EArgumentOutOfRangeException</b>
    ///     is raised.
    ///   </para>
    /// </remarks>
    procedure   Delete(Count: UInt32); virtual;
    /// <summary>
    ///   Clears the buffer and initializes Head and Tail
    /// </summary>
    /// <remarks>
    ///   There is no data overridden, but cannot be accessed any more.
    /// </remarks>
    procedure   Clear; virtual;

    /// <summary>
    ///   Returns an item from the buffer from the given position without removing it
    /// </summary>
    /// <param name="Index">
    ///   Index of the item to be returned. Range is <c>0 .. Count-1</c>. <c>0</c> is same as Head.
    /// </param>
    /// <returns>
    ///   Item at <c>Index</c> position. The item stays in the buffer.
    /// </returns>
    /// <exception cref="EArgumentOutOfRangeException">
    ///   <c>Index</c> exceeds available elements
    /// </exception>
    /// <remarks>
    ///   The allowed range for Index is 0 .. Count-1. If the index is outside this range an
    ///   EArgumentOutOfRangeException is raised. <br />
    /// </remarks>
    function    Peek(Index: UInt32):T; overload;
    /// <summary>
    ///   Retrieves multiple items from the buffer without removing them
    /// </summary>
    /// <param name="Index">
    ///   Index of the first element retrieved. Rangs is <c>0 .. Count-1</c>.
    /// </param>
    /// <param name="Count">
    ///   Number of items to retrieve.
    /// </param>
    /// <returns>
    ///   The items from <c>Index</c> position up to the requested count or less. The buffer content is not changed.
    /// </returns>
    /// <exception cref="EArgumentOutOfRangeException">
    ///   <c>Index</c> exceeds <c>Count - 1</c> or the buffer capacity
    /// </exception>
    /// <remarks>
    ///   <para>
    ///     If Index is larger than <c>Count - 1</c> an <b>EArgumentOutOfRangeException</b> is raised.
    ///   </para>
    ///   <para>
    ///     <c>Count = 0</c> returns an empty array.
    ///   </para>
    ///   <para>
    ///     If more items are requested than are available in the buffer the number of items returned is capped to
    ///     the possible number.
    ///   </para>
    ///   <para>
    ///     If more items are requested than the buffer capacity an <b>EArgumentOutOfRangeException</b> is raised.
    ///   </para>
    /// </remarks>
    function    Peek(Index, Count: UInt32):TRingbufferArray overload;

    /// <summary>
    ///   Returns the number of elements that can be stored in the ring buffer
    /// </summary>
    property Size   : UInt32
      read   GetSize;

    /// <summary>
    ///   Returns the number of items currently in the ring buffer
    /// </summary>
    property Count  : UInt32
      read   GetCount;

    /// <summary>
    ///   This event is triggered by all operations manipulating the number of elements in the ring buffer: Add,Remove,
    ///   Delete...
    /// </summary>
    property Notify : TRingbufferNotify
      read   FNotify
      write  FNotify;
  end;

  /// <summary>
  ///   Ringpuffer for object instances with an option to take ownership of these instances. This allows to free all
  ///   objects still present in the buffer when it is destroyed.
  /// </summary>
  TObjectRingbuffer<T:class> = class(TRingbuffer<T>)
  strict private
    /// <summary>
    ///   Indicates whether the ring buffer takes ownership of the instances
    /// </summary>
    FOwnsObjects : Boolean;
    /// <summary>
    ///   Destroys all object instances currently in the buffer and sets the references to <c>nil</c>
    /// </summary>
    procedure FreeContents;
    /// <summary>
    ///   If <c>FOwnsObjects</c> is set all instances are destroyed and set to <c>nil</c>. If <c>FOwnsObjects</c> is
    ///   not set and the code is running on an ARC platform target all the references are still set to <c>nil</c> to
    ///   avoid memory leaks.
    /// </summary>
    procedure FreeIfOwnedOrARC;
  strict protected
    /// <summary>
    ///   Destroys all instances in a given range of the buffer and/or sets its references to nil.
    /// </summary>
    /// <param name="StartIndex">
    ///   Index of the first item to be deleted. Must be less than <c>EndIndex</c> and in the range <c>0 .. Count - 1</c>
    ///   . Thus wrapped buffer content cannot be deleted in one go.
    /// </param>
    /// <param name="EndIndex">
    ///   Index of the last item to be deleted. Must be larger than <c>StartIndex</c> and in the range <c>0 .. Count -1</c>
    ///   .
    /// </param>
    /// <remarks>
    ///   If <c>FOwnsObjects</c> is set all instances are destroyed and its references set to <c>nil</c>, otherwise
    ///   only the references are set to <c>nil</c>. The latter will decrement the reference count on ARC platforms to
    ///   avoid memory leaks.
    /// </remarks>
    procedure FreeOrNilItems(StartIndex, EndIndex: UInt32); override;
  public
    /// <summary>
    ///   Creates the buffer with the given size
    /// </summary>
    /// <param name="Size">
    ///   Number of items the buffer can hold
    /// </param>
    /// <param name="OwnsObjects">
    ///   True if the buffer shall take ownership over the instances
    /// </param>
    constructor Create(Size: UInt32; OwnsObjects: Boolean = false); overload;
    /// <summary>
    ///   Frees all remaining object instances if <c>OwnsObjects</c> is set.
    /// </summary>
    destructor  Destroy; override;

    /// <summary>
    ///   Removes the given number of elements from the buffers <br />
    /// </summary>
    /// <param name="Count">
    ///   Number of elements to be deleted
    /// </param>
    /// <exception cref="EArgumentOutOfRangeException">
    ///   Count exceeds buffer size <br />
    /// </exception>
    /// <remarks>
    ///   <para>
    ///     If <c>OwnsObjects</c> is set all instances are destroyed.
    ///   </para>
    ///   <para>
    ///     If more elements are to be deleted than are available in the buffer, the buffer is cleared. <br /><br />
    ///     If more elements are to be deleted than the capacity of the buffer an <b>EArgumentOutOfRangeException</b>
    ///     is raised. <br />
    ///   </para>
    /// </remarks>
    procedure   Delete(Count: UInt32); override;
    /// <summary>
    ///   Clears the buffer and initializes Head and Tail. If <c>OwnsObjects</c> is set all object instances are
    ///   destroyed. <br />
    /// </summary>
    procedure   Clear; override;

    /// <summary>
    ///   Indicates whether the ring buffer takes ownership of the instances <br />
    /// </summary>
    property OwnsObjects: Boolean
      read   FOwnsObjects
      write  FOwnsObjects;
  end;


implementation

{ TRingbuffer<T> }

procedure TRingbuffer<T>.Add(Item: T);
begin
  // nur hinzuf�gen wenn entweder noch Platz im Puffer oder wenn Puffer ganz
  // leer (dann sind Start- und Ende Zeiger gleich, aber das FContaisData Flag
  // ist noch false
  if (Count < Size) or ((Count = Size) and not FContainsData) then
  begin
    FItems[FNextFree] := Item;
    AdvanceNextFree(1);

    FContainsData := true;

    if assigned(FNotify) then
      FNotify(Count, evAdd);
  end
  else
    raise EBufferFullException.Create('Capacity of this ringbuffer is exhausted. '+
                                     'Capacity is '+Size.ToString+' Start: '+
                                     FStart.ToString+' End: '+FNextFree.ToString);
end;

procedure TRingbuffer<T>.Add(Items: TRingbufferArray);
var
  FreeItemsAfterEnd : UInt32; // Anzahl freier Elemente zwischen Ende Marker und
                              // Ende des Arrays
begin
  assert(length(Items) > 0, 'Hinzuf�gen eines leeren Arrays ist nicht sinnvoll');

  // ist �berhaupt noch soviel Platz im Puffer?
  // Typecast nach Int64 um W1023 Warnung zu unterdr�cken
  if (length(Items) <= Int64(Size-Count)) then
  begin
    // leeres Array sollte eigentlich nicht vorkommen, aber falls im Release
    // Build Assertions aus sind sollte es auch nicht abst�rzen
    if (length(Items) > 0) then
    begin
      // Passt das �bergebene Array im St�ck in den Puffer und der Puffer Inhalt
      // geht derzeit auch nicht �ber die obere Grenze hinaus, oder muss es
      // gesplittet werden? Typecast nach Int64 um W1023 Warnung zu unterdr�cken
      if (Int64(Size-FNextFree) >= length(Items)) then
        Move(Items[0], FItems[FNextFree], length(Items) * SizeOf(Items[0]))
      else
      begin
        // restlichen Platz im Puffer berechnen
        FreeItemsAfterEnd := Size - FNextFree;
        // von Ende-Marker bis zum Array Ende
        Move(Items[0], FItems[FNextFree], FreeItemsAfterEnd * SizeOf(Items[0]));
        // restliche Daten vom Anfang an
        Move(Items[FreeItemsAfterEnd], FItems[0],
             (UInt32(length(Items))-FreeItemsAfterEnd) * SizeOf(Items[0]));
      end;

      // Endeindex erh�hen
      AdvanceNextFree(length(Items));
      FContainsData := true;

      if assigned(FNotify) then
        FNotify(Count, evAdd);
    end;
  end
  else
    raise EBufferFullException.Create('Capacity of this ringbuffer is exhausted. '+
                                     'Free space is '+(Size-Count).ToString+' Start: '+
                                     FStart.ToString+' End: '+FNextFree.ToString);
end;

procedure TRingbuffer<T>.AdvanceNextFree(Increment: UInt32);
var
  Remaining : UInt32; // Verbleibende Speicherpl�tze bis zur oberen Array Grenze
begin
  Remaining := Size-FNextFree;

  inc(FNextFree, Increment);
  // Ende Marker �ber das Array-Ende hinaus erh�ht
  if (FNextFree > Size-1) then
    FNextFree := (Increment-Remaining);
end;

procedure TRingbuffer<T>.Clear;
begin
  FStart        := 0;
  FNextFree     := 0;
  FContainsData := false;

  if assigned(FNotify) then
    FNotify(0, evRemove);
end;

constructor TRingbuffer<T>.Create(Size: UInt32);
begin
  assert(Size >= 2, 'Puffer mit weniger als 2 Elementen sind nicht sinnvoll!');

  inherited Create;

  SetLength(FItems, Size);
  FStart        := 0;
  FNextFree     := 0;
  FContainsData := false;
  FNotify       := nil;
end;

procedure TRingbuffer<T>.Delete(Count: UInt32);
var
  Remaining : UInt32; // Verbleibende Speicherpl�tze bis zur oberen Array Grenze
begin
  if (Count <= Size) then
  begin
    // Puffer nur teilweise zu l�schen?
    if (Count < self.Count) then
    begin
      Remaining := Size - FStart;
      // Pufferinhalt geht nicht �ber obere Array Grenze hinaus?
      if (Count < Remaining) then
        // Startmarker verschieben
        FStart := FStart + Count
      else
        // Anzahl der Positionen um die insgesamt verschoben werden soll - Anzahl
        // der Positionen bis zum oberen Array Ende abziehen ergibt neue
        // Startposition vom Array-Anfang aus gesehen.
        FStart := (Count - Remaining);

      // nur benachrichtigen wenn �berhaupt was gel�scht werden sollte
      if assigned(FNotify) and (Count > 0) then
        FNotify(Count, evRemove);
    end
    else
      // alles zu l�schen
      Clear;
  end
  else
    raise EArgumentOutOfRangeException.Create('Cannot delete more that buffer '+
                                              'size elements. Size: '+Size.ToString+
                                              ' Elements to be deleted: '+Count.ToString);
end;

destructor TRingbuffer<T>.Destroy;
begin
  SetLength(FItems, 0);

  inherited;
end;

procedure TRingbuffer<T>.FreeOrNilItems(StartIndex, EndIndex: UInt32);
begin
  // absichtlich leer, wird in Kindklasse ausprogrammiert
end;

function TRingbuffer<T>.GetCount: UInt32;
var
  l : Int64;
begin
  // Puffer ist weder komplett leer noch komplett voll
  if (FNextFree <> FStart) then
  begin
    // Je nach dem ob der Puffer gerade �ber das Ende hinaus geht und am Anfang
    // weiter geht
    if (FNextFree > FStart) then
      result := FNextFree-FStart
    else
    begin
      // Puffer geht �ber das Ende hinaus und beginnt am Array Anfang wieder
      l := (length(FItems)-Int64(FStart))+FNextFree;
      result := abs(l);
    end;
  end
  else
    // Start = Ende aber es sind daten da? Dann ist Puffer maximal gef�llt
    if FContainsData then
      result := Size
    else
      // Start = Ende und Puffer ist leer
      result := 0;
end;

function TRingbuffer<T>.GetSize: UInt32;
begin
  result := length(FItems);
end;

function TRingbuffer<T>.Peek(Index: UInt32): T;
var
  reminder : UInt32;
begin
  if (Index < Count) then
  begin
    // Puffer l�uft derzeit nicht �ber seine obere Grenze hinaus
    if ((FStart+Index) < Size) then
      result := FItems[FStart+Index]
    else
    begin
      // um wieviel geht es �ber die obere Grenze hinaus?
      reminder := (FStart+Index)-Size;
      result   := FItems[reminder];
    end;
  end
  else
    raise EArgumentOutOfRangeException.Create('Invalid Index: '+Index.ToString+
                                              ' Max. Index: '+Count.ToString);
end;

function TRingbuffer<T>.Peek(Index, Count: UInt32): TRingbufferArray;
var
  RemoveableCount   : UInt32;  // Anzahl entfernbarer Elemente, meist Count
  RemainingCount    : UInt32;  // Anzahl Elemente von Start bis Pufferende
begin
  // wurden mehr Elemente angefordert als �berhaupt je in den Puffer passen?
  // ist der Index im g�ltigen bereich?
  if (Count <= Size) and (Index < self.Count) then
  begin
    // Ist �berhaupt was im Puffer?
    if (self.Count > 0) then
    begin
      // es sind soviele Elemente im Puffer wie entfernt werden sollen
      if (Count <= self.Count) then
        RemoveableCount := Count
      else
        // Nein, also nur soviele entfernen wie �berhaupt m�glich
        RemoveableCount := self.Count;

      SetLength(result, RemoveableCount);

      // geht der aktuelle Puffer inhalt �ber die obere Grenze (d.h. klappt um)?
      if ((FStart+Index+RemoveableCount) < Size)  then
        // Nein, also Elemente direkt kopierbar
        Move(FItems[FStart+Index], result[0], RemoveableCount * SizeOf(FItems[0]))
      else
      begin
        // 2 Kopieroperationen n�tig
        RemainingCount := (Size-(FStart+Index));
        // von Startzeiger bis Pufferende
        Move(FItems[FStart+Index], result[0], RemainingCount * SizeOf(FItems[0]));

        // von Pufferstart bis Endezeiger
        RemoveableCount := RemoveableCount-RemainingCount;
        Move(FItems[0], result[RemainingCount], RemoveableCount * SizeOf(FItems[0]));
      end;
    end
    else
      SetLength(result, 0);
  end
  else
    raise EArgumentOutOfRangeException.Create('Too many elements requested or '+
                                              'index out of range. Size: '+
                                              Size.ToString+'Index: '+
                                              Index.ToString+' Count: '+Count.ToString);
end;

function TRingbuffer<T>.Remove(RemoveCount: UInt32): TRingbufferArray;
var
  RemoveableCount   : UInt32;  // Anzahl entfernbarer Elemente, meist Count
  RemainingCount    : UInt32;  // Anzahl Elemente von Start bis Pufferende
  StillContainsData : Boolean; // Enth�lt der Puffer nach der Remove Operation
                               // immer noch Daten?
begin
  // wurden mehr Elemente angefordert als �berhaupt je in den Puffer passen?
  if (RemoveCount <= Size) then
  begin
    // Ist �berhaupt was im Puffer?
    if (Count > 0) then
    begin
      // es sind soviele Elemente im Puffer wie entfernt werden sollen
      if (RemoveCount <= Count) then
        RemoveableCount := RemoveCount
      else
        // Nein, also nur soviele entfernen wie �berhaupt m�glich
        RemoveableCount := Count;

      SetLength(result, RemoveableCount);
      // wenn alle Elemente entfernt werden sollen muss Flag hinterher auf False
      // gesetzt werden
      StillContainsData := RemoveCount <> Count;

      // geht der aktuelle Puffer inhalt �ber die obere Grenze (d.h. klappt um)?
      if ((FStart + RemoveableCount) < Size)  then
      begin
        // die Elemente freigeben oder den Referenzz�hler erniedrigen. Kann nur
        // in Kindklassen eine Auswirkung haben, da hier eine leere Operation
        if (RemoveableCount > 0) then
          FreeOrNilItems(FStart, FStart + RemoveableCount - 1);

        // Nein, also Elemente direkt kopierbar
        Move(FItems[FStart], result[0], RemoveableCount * SizeOf(FItems[0]));
        inc(FStart, RemoveableCount);
      end
      else
      begin
        // 2 Kopieroperationen n�tig
        RemainingCount := (Size-FStart);

        // die Elemente freigeben oder den Referenzz�hler erniedrigen. Kann nur
        // in Kindklassen eine Auswirkung haben, da hier eine leere Operation
        if (RemoveableCount > 0) then
          FreeOrNilItems(FStart, FStart + RemainingCount - 1);

        // von Startzeiger bis Pufferende
        Move(FItems[FStart], result[0], RemainingCount * SizeOf(FItems[0]));

        // von Pufferstart bis Endezeiger
        RemoveableCount := RemoveableCount-RemainingCount;

        // die Elemente freigeben oder den Referenzz�hler erniedrigen. Kann nur
        // in Kindklassen eine Auswirkung haben, da hier eine leere Operation
        if (RemoveableCount > 0) then
          FreeOrNilItems(FStart, FStart + RemoveableCount - 1);

        Move(FItems[0], result[RemainingCount], RemoveableCount * SizeOf(FItems[0]));

        FStart := RemoveableCount;
      end;

      FContainsData := StillContainsData;

      if assigned(FNotify) then
        FNotify(RemoveCount, evRemove);
    end
    else
      SetLength(result, 0);
  end
  else
    raise EArgumentOutOfRangeException.Create('Too many elements requested: '+RemoveCount.ToString+
                                              ' Max. possible number: '+Size.ToString);
end;

function TRingbuffer<T>.Remove: T;
var
  i : UInt32;
begin
  // ist �berhaupt was im Puffer?
  if Count > 0 then
  begin
    result := FItems[FStart];

    // das Element freigeben oder den Referenzz�hler erniedrigen. Kann nur in
    // Kindklassen eine Auswirkung haben, da hier eine leere Operation
    FreeOrNilItems(FStart, FStart);

    // Anfangsmarker verschieben
    inc(FStart);
    // obere Grenze �berschritten?
    if (FStart = Size) then
      FStart := 0;

    // wenn Start = Ende ist der Puffer leer
    if (FStart = FNextFree) then
      FContainsData := false;

    if assigned(FNotify) then
      FNotify(Count, evRemove);
  end
  else
    raise EBufferEmptyException.Create('Attempt to remove an item from a '+
                                      'completely empty buffer');
end;

{ TObjectRingbuffer<T> --------------------------------------------------------}

procedure TObjectRingbuffer<T>.Clear;
begin
  // Objekte ggf. freigeben oder bei ARC Referenzz�hler erniedrigen um
  // Speicherlecks zu vermeiden
  FreeIfOwnedOrARC;

  inherited;
end;

constructor TObjectRingbuffer<T>.Create(Size: UInt32; OwnsObjects: Boolean);
begin
  inherited Create(Size);

  FOwnsObjects := OwnsObjects;
end;

procedure TObjectRingbuffer<T>.Delete(Count: UInt32);
begin
  // Sicherheitspr�fung aus dem geerbten Delete muss hier leider dupliziert
  // werden, da sonst ggf. Elemente freigegeben werden, obwohl Delete sp�ter
  // eine Exception ausl�st, weil mehr Elemente gel�scht werden sollten als im
  // Puffer sind!
  if (Count <= Size) then
  begin
    // Freigaberoutine ber�cksichtigt kein �berlauf �ber obere Array Grenze, aber
    // FOwnsObjects wird automatisch ber�cksichtigt
    if (FStart + Count <= Size) then
      FreeOrNilItems(FStart, FStart + Count)
    else
    begin
      // Elemente von Start bis zur oberen Array-Grenze behandeln
      FreeOrNilItems(FStart, Size);
      // Rest ausrechnen und behandeln
      FreeOrNilItems(0, (Count - ((Size - FStart) + 1)) - 1);
    end;

    inherited;
  end
  else
    raise EArgumentOutOfRangeException.Create('Cannot delete more that buffer '+
                                              'size elements. Size: '+Size.ToString+
                                              ' Elements to be deleted: '+Count.ToString);
end;

destructor TObjectRingbuffer<T>.Destroy;
begin
  // Objekte ggf. freigeben oder bei ARC Referenzz�hler erniedrigen um
  // Speicherlecks zu vermeiden
  FreeIfOwnedOrARC;

  inherited;
end;

procedure TObjectRingbuffer<T>.FreeIfOwnedOrARC;
begin
  if FOwnsObjects then
    FreeContents
  else
  begin
    // wenn ARC vorhanden alle Objektreferenzen nillen, da sonst m�glicherweise
    // Speicherlecks entstehen.
    {$IFDEF AUTOREFCOUNT}
    FreeContents;
    {$ENDIF}
  end;
end;

procedure TObjectRingbuffer<T>.FreeContents;
var
  x : T;
  i : Integer;
begin
  // es d�rfen nur die Objekte freigegeben werden, die im derzeit belegten Teil
  // des Ringpuffers gespeichert sind.

  // belegter Teil des Puffers geht derzeit nicht �ber die Grenze hinaus
  if (FStart < FNextFree) then
  begin
    for i := FStart to FNextFree do
      if assigned(FItems[i]) then
        FreeAndNil(FItems[i]);
  end
  else
    if (FStart > FNextFree) then
    begin
      // Bis zum oberen Ende freigeben
      for i := FStart to High(FItems) do
        if assigned(FItems[i]) then
          FreeAndNil(FItems[i]);

      // vom Start bis zum Ende Marker freigeben
      for i := 0 to FNextFree do
        if assigned(FItems[i]) then
          FreeAndNil(FItems[i]);
    end
    else
      // FStart = FNextFree, d.h. Puffer entweder ganz leer oder ganz voll!
      // Wenn FContainsData = true, ist der Puffer ganz voll
      if FContainsData then
        for i := 0 to high(FItems) do
          if assigned(FItems[i]) then
            FreeAndNil(FItems[i]);
end;

procedure TObjectRingbuffer<T>.FreeOrNilItems(StartIndex, EndIndex: UInt32);
var
  i : UInt32;
begin
  assert(EndIndex <= Size, 'Zu hoher Endindex angegeben. Ist: '+
         EndIndex.ToString+' Erlaubt: '+Size.ToString);
  assert(StartIndex <= EndIndex, 'Ung�ltiger Bereich angegeben: '+
         StartIndex.ToString+'/'+EndIndex.ToString);

  if FOwnsObjects then
  begin
    for i := StartIndex to EndIndex do
      FreeAndNil(FItems[i]);
  end
  else
    for i := StartIndex to EndIndex do
      FItems[i] := nil;
end;

end.
