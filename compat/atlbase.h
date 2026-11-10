// Minimal stand-in for ATL's <atlbase.h>, which xwin does not ship (ATL is a separate Visual Studio
// component). Covers only what Luma uses: CComPtr, CA2W and CAtlException.
#pragma once

#include <windows.h>
#include <string>

namespace ATL
{
   template <class T>
   class CComPtr
   {
   public:
      T* p = nullptr;

      CComPtr() noexcept = default;
      CComPtr(T* lp) noexcept : p(lp)
      {
         if (p)
            p->AddRef();
      }
      CComPtr(const CComPtr& other) noexcept : CComPtr(other.p) {}
      CComPtr(CComPtr&& other) noexcept : p(other.p) { other.p = nullptr; }
      ~CComPtr() { Release(); }

      CComPtr& operator=(T* lp) noexcept
      {
         if (lp)
            lp->AddRef();
         Release();
         p = lp;
         return *this;
      }
      CComPtr& operator=(const CComPtr& other) noexcept { return *this = other.p; }
      CComPtr& operator=(CComPtr&& other) noexcept
      {
         if (this != &other)
         {
            Release();
            p = other.p;
            other.p = nullptr;
         }
         return *this;
      }

      // Like ATL, releases the interface and leaves the pointer null.
      void Release() noexcept
      {
         if (T* tmp = p)
         {
            p = nullptr;
            tmp->Release();
         }
      }
      T* Detach() noexcept
      {
         T* tmp = p;
         p = nullptr;
         return tmp;
      }
      void Attach(T* lp) noexcept
      {
         Release();
         p = lp;
      }

      operator T*() const noexcept { return p; }
      T* operator->() const noexcept { return p; }
      T& operator*() const noexcept { return *p; }
      // As in ATL, only valid on an empty pointer (used as an out parameter).
      T** operator&() noexcept { return &p; }
      bool operator!() const noexcept { return p == nullptr; }

      template <class Q>
      HRESULT QueryInterface(Q** other) const noexcept
      {
         return p->QueryInterface(__uuidof(Q), reinterpret_cast<void**>(other));
      }
   };

   class CAtlException
   {
   public:
      HRESULT m_hr;
      CAtlException(HRESULT hr = E_FAIL) noexcept : m_hr(hr) {}
      operator HRESULT() const noexcept { return m_hr; }
   };

   // Narrow to wide string conversion; a null input converts to a null pointer, like ATL.
   class CA2W
   {
   public:
      CA2W(const char* source, UINT code_page = CP_THREAD_ACP)
      {
         if (source == nullptr)
            return;
         const int length = MultiByteToWideChar(code_page, 0, source, -1, nullptr, 0);
         if (length <= 0)
            throw CAtlException(HRESULT_FROM_WIN32(GetLastError()));
         converted.resize(length - 1);
         MultiByteToWideChar(code_page, 0, source, -1, converted.data(), length);
         is_null = false;
      }
      operator const wchar_t*() const noexcept { return is_null ? nullptr : converted.c_str(); }

   private:
      std::wstring converted;
      bool is_null = true;
   };
} // namespace ATL

using namespace ATL;
